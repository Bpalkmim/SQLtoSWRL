-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
-- Arquivo: ParseSQL.lua
-- Autor: Bernardo Alkmim (bpalkmim@gmail.com)
--
-- Um módulo Lua para parsear sentenças em SQL, gerando uma AST em forma de tabela.
-- É necessário ter o pacote lpeg. Recomendo a instalação via Luarocks.
-- Como tanto Bancos de Dados quando Lua têm tabelas, chamaremos tabelas de Lua no
-- decorrer no código de "tables" mesmo, e as de Bancos de Dados de "tablesDB".
-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

local lpeg = require "lpeg"
require "ConstantsForParsing"

-- Define o módulo
ParseSQL = {}

-- TODO 7 parece estourar a pilha por causa de expressões:
-- dentro de chamada de função um caseClause e expressão interna entre parênteses
-- não estoura a pilha com parênteses extra na chamada de função
-- ver como tratar isso

-------------------------------------------------------------------------------------------
-- Definições iniciais
-------------------------------------------------------------------------------------------

-- Variáveis auxiliares para as funções do módulo
local indent = 0
local tabs = ""

-- Strings auxiliares
local errConversion = "Erro de conversão de tabela para string."

-- Tags para a AST.
local tag = ConstantsForParsing.getTag()

-- Elementos Léxicos.
local space 	= lpeg.S(" \n\t")
local skip 		= space^0
local upper 	= lpeg.R("AZ")
local lower 	= lpeg.R("az")
local letter 	= upper + lower

local digit 		= lpeg.R("09")
local integer 		= lpeg.S("-")^-1 * digit^1
local fractional 	= lpeg.P(".") * digit^1
local decimal 		= integer * fractional^-1 + lpeg.S("+-") * fractional
local scientific 	= decimal * lpeg.S("Ee") * integer
local number 		= decimal + scientific

local id 			= (lpeg.P("_") + letter) * (lpeg.S("_-") + letter + digit)^0
local quotedId 		= lpeg.P("\"") * (lpeg.P("\\") * lpeg.P(1) + (1 - lpeg.S("\\\"")))^0 * lpeg.P("\"")
local identifier 	= id + quotedId

local literalString = lpeg.P("'") * (lpeg.P("\\") * lpeg.P(1) + (1 - (lpeg.S("\\'") + lpeg.S("''"))))^0 * lpeg.P("'")

-- Operadores
local compOperator 	= lpeg.C(lpeg.P(">="))
	+ lpeg.C(lpeg.P("<="))
	+ lpeg.C(lpeg.P("!="))
	+ lpeg.C(lpeg.P("<>"))
	+ lpeg.C(lpeg.P(">"))
	+ lpeg.C(lpeg.P("<"))
	+ lpeg.C(lpeg.P("="))
local addOperator 	= lpeg.C(lpeg.P("+"))
	+ lpeg.C(lpeg.P("-"))
local multOperator 	= lpeg.C(lpeg.P("*"))
	+ lpeg.C(lpeg.P("/"))
	+ lpeg.C(lpeg.P("%"))

-- Palavras-chave.
local kw = ConstantsForParsing.getKw()

-- Atualização de identifier com as keywords
local keyWords = lpeg.S("")
for k, _ in pairs(kw) do
	keyWords = keyWords + (kw[k] * -(letter + digit + lpeg.S("_-")))
end
identifier = identifier - keyWords

-------------------------------------------------------------------------------------------
-- Funções locais auxiliares ao módulo
-------------------------------------------------------------------------------------------

-- Função que passa o conteúdo de um arquivo para um string.
local function getContents(fileName)
	local file = assert(io.open(fileName, "r"))
	local contents = file:read("*a")
	file:close()
	return contents
end

-- Função de tageamento de captura.
local function taggedCap(tagging, pat)
	return lpeg.Ct(lpeg.Cg(lpeg.Cc(tagging), "tag") * pat)
end

-- Função que retorna a definição da gramática da entrada, baseada em PostgreSQL.
local function getGrammar()
	-- Preâmbulo: definições dos termos utilizados dentro da gramática.
	-- Parte essencialmente burocrática.
	local commands, command = lpeg.V("commands"), lpeg.V("command")
	local creation, insertion, selection, alteration, deletion =
		lpeg.V("creation"), lpeg.V("insertion"), lpeg.V("selection"),
			lpeg.V("alteration"), lpeg.V("deletion")
	local selectStatement, fromClause, whereClause =
		lpeg.V("selectStatement"), lpeg.V("fromClause"), lpeg.V("whereClause")
	local columns, columnName = lpeg.V("columns"), lpeg.V("columnName")
	local schemaName, tableDBName = lpeg.V("schemaName"), lpeg.V("tableDBName")
	local joinClause, logicExpression = lpeg.V("joinClause"), lpeg.V("logicExpression")
	local simpleExpression, andExpression, compExpression, addExpression, multExpression =
		lpeg.V("simpleExpression"), lpeg.V("andExpression"), lpeg.V("compExpression"),
			lpeg.V("addExpression"), lpeg.V("multExpression")
	local joinOperator, joinConstraint = lpeg.V("joinOperator"), lpeg.V("joinConstraint")
	local asClause, descClause = lpeg.V("asClause"), lpeg.V("descClause")
	local alias = lpeg.V("alias")
	local orderbyClause, groupbyClause = lpeg.V("orderbyClause"), lpeg.V("groupbyClause")
	local functionCall, parameters = lpeg.V("functionCall"), lpeg.V("parameters")
	local caseClause, betweenClause, likeClause, inClause =
		lpeg.V("caseClause"), lpeg.V("betweenClause"), lpeg.V("likeClause"), lpeg.V("inClause")
	local limitClause, offsetClause, havingClause =
		lpeg.V("limitClause"), lpeg.V("offsetClause"), lpeg.V("havingClause")

	-- Definição da gramática em si.
	local grammar = lpeg.P{
		commands,
		commands = taggedCap(tag["root"], (skip * command)^1 * skip * -1);
		command = taggedCap(tag["command"], (creation + insertion + selection + alteration + deletion) * skip * lpeg.P(";"));

		-- Tipos de comandos
		creation = lpeg.P("CREATE"); -- TODO
		insertion = lpeg.P("INSERT"); -- TODO
		alteration = lpeg.P("ALTER"); -- TODO
		deletion = lpeg.P("DELETE"); -- TODO
		selection = taggedCap(tag["select"],
			selectStatement * skip * fromClause * skip * whereClause * skip * groupbyClause
				* skip * orderbyClause * skip * limitClause * skip * offsetClause);

		-- Cláusulas de Select
		selectStatement = taggedCap(tag["selectStmt"], kw["select"] * space^1 * columns);
		fromClause = taggedCap(tag["from"],
			kw["from"] * space^1 * tableDBName * (skip * alias)^-1 * skip * joinClause);
		joinClause = taggedCap(tag["join"],
			joinOperator * space^1 * tableDBName * (skip * alias)^-1 * skip * joinConstraint * skip)^1
			+ (lpeg.P(",") * skip * tableDBName * (skip * alias)^-1 * skip)^1
			+ skip;
		whereClause = taggedCap(tag["where"], kw["where"] * skip * logicExpression)
			+ skip;
		groupbyClause = taggedCap(tag["groupby"],
			kw["groupby"] * space^1 * taggedCap(tag["columns"], (columnName * skip * lpeg.P(",") * skip)^0 * columnName))
				* skip * havingClause
			+ skip;
		havingClause = taggedCap(tag["having"], kw["having"] * skip * logicExpression)
			+ skip;
		orderbyClause = taggedCap(tag["orderby"],
			kw["orderby"] * space^1 * taggedCap(tag["columns"],
				(descClause * skip * lpeg.P(",") * skip)^0 * skip * descClause))
			+ skip;
		limitClause = taggedCap(tag["limit"],
			kw["limit"] *
				(taggedCap(tag["all"], space^1 * kw["all"])
				+ skip * logicExpression))
			+ skip;
		offsetClause = taggedCap(tag["offset"], kw["offset"] * skip * logicExpression)
			+ skip;

		-- Hierarquia de expressões, a fim de implementar prioridade de operadores já na gramática
		-- Implementação de associatividade à esquerda ou à direita ocorrerá na análise semântica
		-- Teve de ser tomado um cuidado com as keywords "OR" e "ORDER BY", para evitar confusão
		-- com "HAVING" (que é seguido de uma expressão) e "ORDER BY" na mesma query.
		logicExpression = taggedCap(tag["or"],
			andExpression * (skip * (kw["or"] - kw["orderby"]) * skip * andExpression)^1)
			+ andExpression;
		andExpression = taggedCap(tag["and"],
			compExpression * (skip * kw["and"] * space^1 * compExpression)^1)
			+ compExpression;
		compExpression = betweenClause
			+ likeClause
			+ inClause
			+ taggedCap(tag["comp"],
				addExpression * skip * (compOperator * skip * addExpression * skip)^1)
			+ addExpression;
		addExpression = taggedCap(tag["add"],
				multExpression * skip *	(addOperator * skip * multExpression * skip)^1)
			+ multExpression;
		multExpression = taggedCap(tag["mult"],
				simpleExpression * skip * (multOperator * skip * simpleExpression * skip)^1)
			+ simpleExpression;
		simpleExpression = lpeg.C(kw["true"])
			+ lpeg.C(kw["false"])
			+ taggedCap(tag["date"],
				kw["date"] * skip * taggedCap(tag["litString"], lpeg.C(literalString)))
			+ taggedCap(tag["interval"],
				kw["interval"] * skip * taggedCap(tag["litString"], lpeg.C(literalString)))
			+ taggedCap(tag["not"], kw["not"] * skip * logicExpression)
			+ lpeg.C(kw["null"])
			+ caseClause
			+ functionCall
			+ columnName
			+ taggedCap(tag["number"], lpeg.C(number))
			+ taggedCap(tag["litString"], lpeg.C(literalString))
			+ skip * lpeg.P("(") * skip * logicExpression * skip * lpeg.P(")") * skip;

		-- Cláusulas de expressões
		betweenClause = taggedCap(tag["between"],
			addExpression * skip * ((taggedCap(tag["not"],
				kw["not"] * space^1 * kw["between"] * skip * addExpression * skip
					* kw["and"] * skip * addExpression))
				+ kw["between"] * skip * addExpression * skip
					* kw["and"] * skip * addExpression));
		likeClause = taggedCap(tag["like"],
			addExpression * skip * (taggedCap(tag["not"],
				kw["not"] * space^1 * kw["like"] * skip * addExpression * skip * (taggedCap(tag["escape"],
					kw["escape"] * skip * addExpression))^-1)
				+ kw["like"] * skip * addExpression * skip * (taggedCap(tag["escape"],
					kw["escape"] * skip * addExpression))^-1));
		inClause = taggedCap(tag["in"],
			addExpression * skip * (kw["in"] - (kw["interval"] + kw["inner"]))
				* skip * lpeg.P("(") * skip * addExpression * skip *
					(lpeg.P(",") * skip * addExpression * skip)^0 * lpeg.P(")"));
		caseClause = taggedCap (tag["case"],
			kw["case"] * space^1 * kw["when"] * skip * logicExpression * skip *
				kw["then"] * skip * logicExpression * skip *
				kw["else"] * skip * logicExpression * skip * kw["end"] * skip);

		-- Chamada de função
		functionCall = taggedCap(tag["function"],
			lpeg.C(identifier) * skip * lpeg.P("(") * skip * parameters * skip * lpeg.P(")") * skip);
		parameters = logicExpression * skip * (lpeg.P(",") * skip * logicExpression * skip)^0;

		-- Identificadores
		columnName = taggedCap(tag["distinct"],
			kw["distinct"] * space^1 * taggedCap(tag["colId"],
				((schemaName * lpeg.P("."))^-1 * tableDBName * lpeg.P("."))^-1
					* (lpeg.C(lpeg.P("*")) + lpeg.C(identifier))))
			+ taggedCap(tag["colId"],
				((schemaName * lpeg.P("."))^-1 * tableDBName * lpeg.P("."))^-1
					* (lpeg.C(lpeg.P("*")) + lpeg.C(identifier)));
		schemaName = taggedCap(tag["id"], lpeg.C(identifier));
		tableDBName = taggedCap(tag["id"], lpeg.C(identifier));
		alias = taggedCap(tag["alias"], lpeg.C(identifier));

		-- Auxiliares para o Select
		columns = taggedCap(tag["columns"],
			lpeg.C(lpeg.P("*"))
			+ (asClause * skip * lpeg.P(",") * skip)^0 * asClause);
		asClause = taggedCap(tag["as"], logicExpression * skip * kw["as"] * space^1 * alias)
			+ columnName;
		joinConstraint = taggedCap(tag["on"], kw["on"] * space^1 * logicExpression)
			+ taggedCap(tag["using"], kw["using"] * skip * lpeg.P("(") * skip * columns * skip * lpeg.P(")"))
			+ skip;
		joinOperator = taggedCap(tag["natural"], kw["natural"])^-1 * skip *
			(taggedCap(tag["inner"], kw["inner"]) * space^1
				+ taggedCap(tag["cross"], kw["cross"]) * space^1
				+ (taggedCap(tag["left"], kw["left"]) * space^1
					+ (taggedCap(tag["outer"], kw["outer"]) * space^1)
					+ skip)) * kw["join"];
		descClause = taggedCap(tag["desc"], columnName * space^1 * kw["desc"])
			+ columnName;
	}

	return grammar
end

-------------------------------------------------------------------------------------------
-- Funções externas do módulo
-------------------------------------------------------------------------------------------

-- Função que parseia a entrada e retorna a árvore de sintaxe abstrata em forma de tabela Lua.
-- Recebe um arquivo com o código SQL.
function ParseSQL.parseInput(fileName)
	local contents = getContents(fileName)
	local t = lpeg.match(getGrammar(), contents)
	assert(t, "Falha no reconhecimento de "..contents)
	return t
end

-- Função que recebe a AST e retorna sua representação em string.
function ParseSQL.printAST(ast)

	-- Variável que indica qual o espaço utilizado na representação da AST
	local spacing = "\t"

	if type(ast) == "number" then
		return ast
	elseif type(ast) == "string" then
		return string.format("%s", ast)
	elseif type(ast) == "table" then
		local s = "{ \n"
		indent = indent + 1

		for k, v in pairs(ast) do
			local initTabs = tabs
			for _ = #initTabs, indent-1 do
				tabs = tabs..spacing
			end

			s = s..tabs.."[ "..ParseSQL.printAST(k).." -> "..ParseSQL.printAST(v).." ]\n"
			tabs = initTabs
		end

		s = s..tabs.."}"
		tabs = ""
		indent = indent - 1
		return s
	else
		print(errConversion)
	end
end