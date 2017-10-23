-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
-- Arquivo: GenerateSWRL.lua
-- Autor: Bernardo Alkmim (bpalkmim@gmail.com)
--
-- Módulo que gera código SWRL partindo de uma AST de SQL.
-- É necessário ter o pacote lpeg. Recomendo a instalação via Luarocks.
-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

require "ParseSQL"
require "ConstantsForParsing"

-- Define o módulo.
GenerateSWRL = {}

-- TODO ver como lidar com and e or (diferença semântica)

-- Índice que indica qual a subexpressão de AND atual.
local currAnd = 0

-- Índice que indica qual a subexpressão de OR atual.
local currOr = 0

-- Tags para a AST.
local tag = ConstantsForParsing.getTag()

-------------------------------------------------------------------------------------------
-- Funções locais auxiliares ao módulo
-------------------------------------------------------------------------------------------

-- Função que gera uma regra em SWRL em formato de string.
-- TODO ver quais deverão ser delegados a expressções menores (add, colId etc)
-- TODO provavelmente:
-- os que apresentam ?col (e ?nameCol) são relacionados a colId
-- ?comp claramente delegado à comparação (e ?dComp, e ?op)
local function generateRule(ast)
	local s = ""

	-- Todas as regras apresentam este cabeçalho TODO todas mesmo????
	s = s..[[Predicate(?pred) ^
	hasDescription(?pred, ?desc)
	]]

	s = s.."swrlb:substringBefore(?exp"..currAnd..", ?desc, \" AND \") ^\n"
	s = s.."swrlb:substringBefore(?expOr"..currOr..", ?exp"..currAnd..", \" OR \") ^\n"

	s = s.."CompositeExpression(?pred) ^\n"

	-- Identificador????
	s = s.."Column(?col) ^\n"
	s = s.."hasName(?col, ?nameCol) ^\n"
	s = s.."swrlb:contains(?desc, ?nameCol) ^\n"

	-- Comparação????
	s = s.."ComparisonOperator(?comp) ^\n"
	s = s.."hasDescription(?comp, ?dComp) ^\n"
	s = s.."swrlb:contains(?desc, ?dComp) ^\n"
	s = s.."swrlb:tokenize(?op, ?expOr"..currOr..", \" \") ^\n"
	s = s.."swrlb:stringEqualIgnoreCase(?dComp, ?op) ^\n"

	s = s.."swrlx:makeOWLThing(?simple, ?expOr"..currOr..")\n"

	-- Todas as regras apresentam essa finalização TODO todas mesmo????
	s = s.."-> Predicate(?simple) ^\n"
	s = s.."SimpleExpression(?simple) ^\n"
	s = s.."hasDescription(?simple, ?exp"..currAnd..") ^\n"

	-- Identificador????
	s = s.."ExpressionObject(?col) ^\n"
	s = s.."ReferencedColumn(?col) ^\n"
	s = s.."componentOf(?col, ?pred) ^\n"

	-- Comparação????
	s = s.."componentOf(?comp, ?pred)\n"

	return s
end

-- Função que percorre a AST preenchendo a string de saída com o código SWRL de acordo.
local function scanAST(ast)
	local ret = ""

	assert(type(ast) == "table", "AST não é uma tabela Lua.")

	if ast["tag"] ~= nil then

		if ast["tag"] == tag["where"] then
			ret = ret..scanAST(ast[1])

		elseif ast["tag"] == tag["or"] then
			for _, v in ipairs(ast) do
				ret = ret..scanAST(v)
				-- Prepara para atualizar a próxima expressão
				currOr = currOr + 1
			end
			
		elseif ast["tag"] == tag["and"] then
			for _, v in ipairs(ast) do
				ret = ret..scanAST(v)
				-- Prepara para atualizar a próxima expressão
				currAnd = currAnd + 1
			end

		elseif ast["tag"] == tag["comp"] then
			ret = ret..generateRule(ast)
		elseif ast["tag"] == tag["mult"] then

		elseif ast["tag"] == tag["add"] then
			
		elseif ast["tag"] == tag["colId"] then
			
		elseif ast["tag"] == tag["date"] then

		elseif ast["tag"] == tag["interval"] then

		-- Casos de nós da AST que não estão dentro do WHERE de SQL.
		else
			for _, v in ipairs(ast) do
				ret = ret..scanAST(v)
			end
		end
	end
	return ret
end

-- Função que cria um arquivo cujo conteúdo é a string passada por parâmetro, indexando de
-- acordo com o parâmetro passado. O formato do nome é "output"..i..".swrl"
local function createOutputFile(text, i)
	local file = assert(io.open("output"..i.."", "w"))
	file:write(text)
	file:close()
end

-------------------------------------------------------------------------------------------
-- Funções externas do módulo
-------------------------------------------------------------------------------------------

-- Função principal do módulo que recebe um arquivo de um código escrito em SQL, faz sua
-- AST e cria um arquivo em SWRL.
function GenerateSWRL.generateOutput(fileName, index)
	local ast = ParseSQL.parseInput(fileName)
	local out = scanAST(ast)
	createOutputFile(out, index)
end

--[[



]]