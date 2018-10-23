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

-- Índice que indica qual a subexpressão de AND atual.
local currAnd = 0

-- Índice que indica qual a subexpressão de OR atual.
local currOr = 0

-- Tags para a AST.
local tag = ConstantsForParsing.getTag()

-- Lista com as regras (utilizada com a presença de OR no SQL, o que quebra as regras de
-- SWRL em mais de uma).
local rules = {}

-- Listas para guardar os componentes das expressões do WHERE da query SQL
local idList = {}
local litList = {}
local expList = {}
local operList = {}

-------------------------------------------------------------------------------------------
-- Funções locais auxiliares ao módulo
-------------------------------------------------------------------------------------------

-- Gera a descrição de um nó da AST, que é basicamente uma string indicando toda a expressão do nó.
local function formDescription(ast)
	local description = ""

	if ast["tag"] ~= nil then
		if ast["tag"] == tag["and"] then
			for _, v in ipairs(ast) do
				description = description..formDescription(v).." AND "
			end
			description = description:sub(1, -6)

		-- TODO verificar se esse passo é realmente necessário. Teoricamente nunca vemos um OR aqui.
		elseif ast["tag"] == tag["or"] then
			for _, v in ipairs(ast) do
				description = description..formDescription(v).." OR "
			end
			description = description:sub(1, -5)

		elseif ast["tag"] == tag["comp"] or ast["tag"] == tag["add"] or ast["tag"] == tag["mult"] then
			description = formDescription(ast[1]).." "..ast[2].." "..formDescription(ast[3])

		elseif ast["tag"] == tag["between"] then
			description = formDescription(ast[1]).." between "..formDescription(ast[2]).." and "..formDescription(ast[3])

		elseif ast["tag"] == tag["like"] then
			description = formDescription(ast[1]).." like "..formDescription(ast[2])

		elseif ast["tag"] == tag["in"] then
			description = formDescription(ast[1]).." in ("
			for i, v in ipairs(ast) do
				if i > 1 then
					description = description..formDescription(v)..", "
				end
			end
			description = description:sub(1, -3)..")"

		elseif ast["tag"] == tag["number"] or ast["tag"] == tag["colId"] or ast["tag"] == tag["litString"] then
			description = ast[1]

		elseif ast["tag"] == tag["date"] or ast["tag"] == tag["interval"] then
			description = ast["tag"].." "..formDescription(ast[1])

		else
			description = formDescription(ast[1])
		end

		-- TODO demais tags
	end

	return description
end

-- Função que "amortiza" os Or que estiverem encadeados em outros Or, e And em And.
local function levelLogicalOperators(ast)

	if ast["tag"] == tag["or"] then
		for k, v in ipairs(ast) do
			ast[k] = levelLogicalOperators(ast[k])

			if v["tag"] == tag["or"] then
				table.remove(ast, k)
				for i, _ in ipairs(ast[k]) do
					table.insert(ast, v[i])
				end
			end
		end

	elseif ast["tag"] == tag["and"] then
		for k, v in ipairs(ast) do
			ast[k] = levelLogicalOperators(ast[k])

			if v["tag"] == tag["and"] then
				table.remove(ast, k)
				for i, _ in ipairs(ast[k]) do
					table.insert(ast, v[i])
				end
			end
		end
	end

	return ast
end

-- Função recursiva que transforma as cláusulas do 'where' AST em forma normal disjuntiva,
-- ou seja, disjunções de conjunções. Isso é útil para simularmos o ∨ em SWRL. Ela retorna o novo
-- nó da AST já alterado.
-- Vale notar que nossos ∨ e ∧ são generalizados (são listas de fórmulas com tamanhos variáveis).
-- k aqui é apenas utilizado para a recursão caso tenhamos uma conjunção
local function turnToDNF(ast)

	if type(ast) == "table" then

		-- Com ∨ externos, basta que vejamos se há algum OR nas fómulas de dentro, mantendo a
		-- estrutura externa, que já é uma disjunção.
		if ast["tag"] == tag["or"] then
			for i in ipairs(ast) do
				ast[i] = turnToDNF(ast[i])
			end

			return ast

		-- Com ∧, devemos ver se o primeiro é um ∨. Se for, quebramos a expressão.
		-- Caso contrário, verificamos recursivamente o resto da lista.
		elseif ast["tag"] == tag["and"] then
			local foundOr = 0
			-- Encontra o primeiro Or que aparece no And
			for i, v in ipairs(ast) do
				if v["tag"] == tag["or"] then
					foundOr = i
					break
				end
			end

			-- Caso não tenha sido encontrado nenhum Or, apenas chama recursivamente
			-- para as fórmulas de dentro (e, como elas vão trazer seus Or para a
			-- "superfície", passamos a chamada da função de novo)
			if foundOr == 0 then
				local newAstNode = {tag = tag["and"]}
				for i, _ in ipairs(ast) do
					table.insert(newAstNode, turnToDNF(ast[i]))
				end

				-- Verifica-se de novo, após a recursão se ainda está presente algum Or
				foundOr = 0
				-- Encontra o primeiro Or que aparece no And
				for i, v in ipairs(newAstNode) do
					if v["tag"] == tag["and"] then
						foundOr = i
						break
					end
				end

				-- Caso nenhum Or tenha sido encontrado, o nó está em DNF
				if foundOr == 0 then
					return newAstNode
				-- Caso contrário, precisamos da função novamente para trazer os Or
				-- de dentro para a superfície
				else
					return turnToDNF(newAstNode)
				end

			-- Caso tenha sido encontrado, distribui-se esse Or pela fórmula.
			else
				local newAstNode = {tag = tag["or"]}
				for j, _ in ipairs(ast[foundOr]) do
					local newInternalNode = {tag = tag["and"]}

					for i, _ in ipairs(ast) do
						if i == foundOr then
							table.insert(newInternalNode, ast[i][j])
						else -- Demais nós são mantidos
							table.insert(newInternalNode, ast[i])
						end
					end
					table.insert(newAstNode, newInternalNode)
				end

				return turnToDNF(newAstNode)

			end

		else
			-- Caso "atômico": é uma coluna, ou expressão comparativa, aditiva etc., ou um literal,
			-- entre outros. Para a organização dos ∧ e ∨, é atômico.
			return ast
		end
	end

	return ast

end

-- Função que busca um operador OR na AST dada, retornando um booleano.
local function findOr(ast)
	if type(ast) == "table" then
		if ast["tag"] == tag["or"] then
			return true
		else
			local ret = false
			for i, _ in ipairs(ast) do
				ret = ret or findOr(ast[i])
			end

			return ret
		end
	end

	return false
end

-- Função que percorre a AST preenchendo a string de saída com o código SWRL de acordo.
-- ?pred se refere ao predicado inteiro.
-- Os demais componentes do predicado estarão presentes nas listas auxiliares.
local function scanAST(ast)
	-- Parte do antecedente da saída
	local retAnt = ""
	-- Parte do consequente da saída
	local retCon = ""

	-- Auxiliares
	local retAntAux, retConAux

	assert(type(ast) == "table", "AST não é uma tabela Lua.")

	if ast["tag"] ~= nil then
		if ast["tag"] == tag["and"] then
			for i, v in ipairs(ast) do
				currAnd = currAnd + 1
				if i > 1 then
					retAnt = retAnt.."swrlb:substringAfter(?and1, ?desc, \" "..tag["and"].." \") ^\n"
					for j=2,(i-1) do
						retAnt = retAnt.."swrlb:substringAfter(?and"..j..", ?and"..(j-1)..", \" "..tag["and"].." \") ^\n"
					end
					retAnt = retAnt.."swrlb:substringBefore(?and0, ?and"..(currAnd-1)..", \" "..tag["and"].." \") ^\n"
				end
				retCon = retCon.."componentOf(?and"..(currAnd-1)..", ?pred) ^\n"
				retAntAux, retConAux = scanAST(v)
				retAnt = retAnt..retAntAux
				retCon = retCon..retConAux
			end

		elseif ast["tag"] == tag["comp"] then
			table.insert(expList, ast)
			table.insert(operList, ast[2])

			if currAnd == 0 and currOr == 0 then
				retAnt = retAnt.."swrlb:matches(?desc, ?or"..currOr..") ^\n"
			end

			retAnt = retAnt.."ComparisonOperator(?comp"..#operList..") ^\n"
			retAnt = retAnt.."hasDescription(?comp"..#operList..", ?dComp"..#operList..") ^\n"
			retAnt = retAnt.."swrlb:contains(?desc, ?dComp"..#operList..") ^\n"
			if currAnd == 0 then
				retAnt = retAnt.."swrlb:tokenize(?op"..#operList..", ?or"..currOr..", \" \") ^\n"
			else
				retAnt = retAnt.."swrlb:tokenize(?op"..#operList..", ?and"..(currAnd-1)..", \" \") ^\n"
			end
			retAnt = retAnt.."swrlb:stringEqualIgnoreCase(?dComp"..#operList..", ?op"..#operList..") ^\n"
			if currAnd == 0 then
				retAnt = retAnt.."swrlx:makeOWLThing(?simple"..#operList..", ?pred) ^\n"
			else
				retAnt = retAnt.."swrlx:makeOWLThing(?simple"..#operList..", ?and"..(currAnd-1)..") ^\n"
			end

			retCon = retCon.."ExpressionObject(?comp"..#operList..") ^\n"
			retCon = retCon.."componentOf(?comp"..#operList..", ?simple"..#expList..") ^\n"
			if currAnd == 0 then
				retCon = retCon.."componentOf(?simple"..#operList..", ?pred) ^\n"
			else
				retCon = retCon.."componentOf(?simple"..#operList..", ?and"..(currAnd-1)..") ^\n"
			end
			retCon = retCon.."SimpleExpression(?simple"..#expList..") ^\n"

			-- Chamadas para as partes esquerda e direita da expressão comparativa
			retAntAux, retConAux = scanAST(ast[1])
			if ast[1]["tag"] ~= tag["colId"] then -- É um literal
				retAnt = retAnt.."swrlb:substringBefore(?lit"..#litList..", ?simple"..#expList..", ?dcomp"..#operList..") ^\n"
			end
			retAnt = retAnt..retAntAux
			retCon = retCon..retConAux

			retAntAux, retConAux = scanAST(ast[3])
			if ast[3]["tag"] ~= tag["colId"] then -- É um literal
				retAnt = retAnt.."swrlb:substringAfter(?lit"..#litList..", ?simple"..#expList..", ?dcomp"..#operList..") ^\n"
			end
			retAnt = retAnt..retAntAux
			retCon = retCon..retConAux

		elseif ast["tag"] == tag["like"] then
			table.insert(expList, ast)
			table.insert(operList, "like")

			if currAnd == 0 and currOr == 0 then
				retAnt = retAnt.."swrlb:matches(?desc, ?or"..currOr..") ^\n"
			end

			retAnt = retAnt.."ComparisonOperator(?comp"..#operList..") ^\n"
			retAnt = retAnt.."hasDescription(?comp"..#operList..", ?dComp"..#operList..") ^\n"
			retAnt = retAnt.."swrlb:contains(?desc, ?dComp"..#operList..") ^\n"
			if currAnd == 0 then
				retAnt = retAnt.."swrlb:tokenize(?op"..#operList..", ?or"..currOr..", \" \") ^\n"
			else
				retAnt = retAnt.."swrlb:tokenize(?op"..#operList..", ?and"..(currAnd-1)..", \" \") ^\n"
			end
			retAnt = retAnt.."swrlb:stringEqualIgnoreCase(?dComp"..#operList..", ?op"..#operList..") ^\n"
			if currAnd == 0 then
				retAnt = retAnt.."swrlx:makeOWLThing(?simple"..#operList..", ?pred) ^\n"
			else
				retAnt = retAnt.."swrlx:makeOWLThing(?simple"..#operList..", ?and"..(currAnd-1)..") ^\n"
			end

			retCon = retCon.."ExpressionObject(?comp"..#operList..") ^\n"
			retCon = retCon.."componentOf(?comp"..#operList..", ?simple"..#expList..") ^\n"
			if currAnd == 0 then
				retCon = retCon.."componentOf(?simple"..#operList..", ?pred) ^\n"
			else
				retCon = retCon.."componentOf(?simple"..#operList..", ?and"..(currAnd-1)..") ^\n"
			end
			retCon = retCon.."SimpleExpression(?simple"..#expList..") ^\n"

			-- Chamadas para as partes esquerda e direita do Like
			retAntAux, retConAux = scanAST(ast[1])
			if ast[1]["tag"] ~= tag["colId"] then -- É um literal
				retAnt = retAnt.."swrlb:substringAftertringBefore(?lit"..#litList..", ?simple"..#expList..", ?dcomp"..#operList..") ^\n"
			end
			retAnt = retAnt..retAntAux
			retCon = retCon..retConAux

			retAntAux, retConAux = scanAST(ast[2])
			if ast[2]["tag"] ~= tag["colId"] then -- É um literal
				retAnt = retAnt.."swrlb:substringAfter(?lit"..#litList..", ?simple"..#expList..", ?dcomp"..#operList..") ^\n"
			end
			retAnt = retAnt..retAntAux
			retCon = retCon..retConAux

		elseif ast["tag"] == tag["in"] then
			table.insert(expList, ast)
			table.insert(operList, "in")

			if currAnd == 0 and currOr == 0 then
				retAnt = retAnt.."swrlb:matches(?desc, ?or"..currOr..") ^\n"
			end

			retAnt = retAnt.."ComparisonOperator(?comp"..#operList..") ^\n"
			retAnt = retAnt.."hasDescription(?comp"..#operList..", ?dComp"..#operList..") ^\n"
			retAnt = retAnt.."swrlb:contains(?desc, ?dComp"..#operList..") ^\n"
			if currAnd == 0 then
				retAnt = retAnt.."swrlb:tokenize(?op"..#operList..", ?or"..currOr..", \" \") ^\n"
			else
				retAnt = retAnt.."swrlb:tokenize(?op"..#operList..", ?and"..(currAnd-1)..", \" \") ^\n"
			end
			retAnt = retAnt.."swrlb:stringEqualIgnoreCase(?dComp"..#operList..", ?op"..#operList..") ^\n"
			if currAnd == 0 then
				retAnt = retAnt.."swrlx:makeOWLThing(?simple"..#operList..", ?pred) ^\n"
			else
				retAnt = retAnt.."swrlx:makeOWLThing(?simple"..#operList..", ?and"..(currAnd-1)..") ^\n"
			end

			retCon = retCon.."ExpressionObject(?comp"..#operList..") ^\n"
			retCon = retCon.."componentOf(?comp"..#operList..", ?simple"..#expList..") ^\n"
			if currAnd == 0 then
				retCon = retCon.."componentOf(?simple"..#operList..", ?pred) ^\n"
			else
				retCon = retCon.."componentOf(?simple"..#operList..", ?and"..(currAnd-1)..") ^\n"
			end
			retCon = retCon.."SimpleExpression(?simple"..#expList..") ^\n"

			-- Chamadas para a parte esquerda do In
			retAntAux, retConAux = scanAST(ast[1])
			if ast[1]["tag"] ~= tag["colId"] then -- É um literal
				retAnt = retAnt.."swrlb:substringBefore(?lit"..#litList..", ?simple"..#expList..", ?dcomp"..#operList..") ^\n"
			end
			retAnt = retAnt..retAntAux
			retCon = retCon..retConAux

			-- Lidando com a lista à direita do In como um Literal
			local list = "("
			for i, v in ipairs(ast) do
				if i > 1 then
					list = list..formDescription(v)..", "
				end
			end
			list = list:sub(1, -3)..")"

			table.insert(litList, list)

			retAnt = retAnt.."swrlb:substringAfter(?lit"..#litList..", ?simple"..#expList..", ?dcomp"..#operList..") ^\n"
			retAnt = retAnt.."hasDescription(?lit"..#litList..", dLit"..#litList..") ^\n"
			retAnt = retAnt.."swrlb:contains(?desc, ?dLit"..#litList..") ^\n"
			retAnt = retAnt.."swrlx:makeOWLThing(?lit"..#litList..", ?simple"..#operList..") ^\n"

			retCon = retCon.."Literal(?lit"..#litList..") ^\n"
			retCon = retCon.."componentOf(?lit"..#litList..", ?simple"..#expList..") ^\n"
			retCon = retCon.."ExpressionObject(?lit"..#litList..") ^\n"

		elseif ast["tag"] == tag["between"] then
			table.insert(expList, ast)
			table.insert(operList, "between")

			if currAnd == 0 and currOr == 0 then
				retAnt = retAnt.."swrlb:matches(?desc, ?or"..currOr..") ^\n"
			end

			retAnt = retAnt.."ComparisonOperator(?comp"..#operList..") ^\n"
			retAnt = retAnt.."hasDescription(?comp"..#operList..", ?dComp"..#operList..") ^\n"
			retAnt = retAnt.."swrlb:contains(?desc, ?dComp"..#operList..") ^\n"
			if currAnd == 0 then
				retAnt = retAnt.."swrlb:tokenize(?op"..#operList..", ?or"..currOr..", \" \") ^\n"
			else
				retAnt = retAnt.."swrlb:tokenize(?op"..#operList..", ?and"..(currAnd-1)..", \" \") ^\n"
			end
			retAnt = retAnt.."swrlb:stringEqualIgnoreCase(?dComp"..#operList..", ?op"..#operList..") ^\n"
			if currAnd == 0 then
				retAnt = retAnt.."swrlx:makeOWLThing(?simple"..#operList..", ?pred) ^\n"
			else
				retAnt = retAnt.."swrlx:makeOWLThing(?simple"..#operList..", ?and"..(currAnd-1)..") ^\n"
			end

			retCon = retCon.."ExpressionObject(?comp"..#operList..") ^\n"
			retCon = retCon.."componentOf(?comp"..#operList..", ?simple"..#expList..") ^\n"
			if currAnd == 0 then
				retCon = retCon.."componentOf(?simple"..#operList..", ?pred) ^\n"
			else
				retCon = retCon.."componentOf(?simple"..#operList..", ?and"..(currAnd-1)..") ^\n"
			end
			retCon = retCon.."SimpleExpression(?simple"..#expList..") ^\n"

			-- Chamadas para a parte esquerda
			retAntAux, retConAux = scanAST(ast[1])
			if ast[1]["tag"] ~= tag["colId"] then -- É um literal
				retAnt = retAnt.."swrlb:substringBefore(?lit"..#litList..", ?simple"..#expList..", ?dcomp"..#operList..") ^\n"
			end
			retAnt = retAnt..retAntAux
			retCon = retCon..retConAux

			-- Lidamos com o "x and y" do between como um literal
			local desc = formDescription(ast[2]).." and "..formDescription(ast[3])
			table.insert(litList, desc)

			retAnt = retAnt.."swrlb:substringAfter(?lit"..#litList..", ?simple"..#expList..", ?dcomp"..#operList..") ^\n"
			retAnt = retAnt.."hasDescription(?lit"..#litList..", dLit"..#litList..") ^\n"
			retAnt = retAnt.."swrlb:contains(?desc, ?dLit"..#litList..") ^\n"
			retAnt = retAnt.."swrlx:makeOWLThing(?lit"..#litList..", ?simple"..#operList..") ^\n"

			retCon = retCon.."Literal(?lit"..#litList..") ^\n"
			retCon = retCon.."componentOf(?lit"..#litList..", ?simple"..#expList..") ^\n"
			retCon = retCon.."ExpressionObject(?lit"..#litList..") ^\n"

		elseif ast["tag"] == tag["mult"] or ast["tag"] == tag["add"] then
			table.insert(litList, formDescription(ast))
			retAnt = retAnt.."hasDescription(?lit"..#litList..", dLit"..#litList..") ^\n"
			retAnt = retAnt.."swrlb:contains(?desc, ?dLit"..#litList..") ^\n"
			retAnt = retAnt.."swrlx:makeOWLThing(?lit"..#litList..", ?simple"..#operList..") ^\n"

			retCon = retCon.."Literal(?lit"..#litList..") ^\n"
			retCon = retCon.."componentOf(?lit"..#litList..", ?simple"..#expList..") ^\n"
			retCon = retCon.."ExpressionObject(?lit"..#litList..") ^\n"

		elseif ast["tag"] == tag["colId"] then
			table.insert(idList, ast[1])
			retAnt = retAnt.."Column(?col"..#idList..") ^\n"
			retAnt = retAnt.."hasName(?col"..#idList..", ?nameCol"..#idList..") ^\n"
			retAnt = retAnt.."swrlb:contains(?desc, ?nameCol"..#idList..") ^\n"

			retCon = retCon.."ReferencedColumn(?col"..#idList..") ^\n"
			retCon = retCon.."ExpressionObject(?col"..#idList..") ^\n"
			retCon = retCon.."componentOf(?col"..#idList..", ?simple"..#expList..") ^\n"

		elseif ast["tag"] == tag["date"] or ast["tag"] == tag["interval"] then
			table.insert(litList, ast["tag"].." "..formDescription(ast[1]))
			retAnt = retAnt.."hasDescription(?lit"..#litList..", dLit"..#litList..") ^\n"
			retAnt = retAnt.."swrlb:contains(?desc, ?dLit"..#litList..") ^\n"
			retAnt = retAnt.."swrlx:makeOWLThing(?lit"..#litList..", ?simple"..#operList..") ^\n"

			retCon = retCon.."Literal(?lit"..#litList..") ^\n"
			retCon = retCon.."componentOf(?lit"..#litList..", ?simple"..#expList..") ^\n"
			retCon = retCon.."ExpressionObject(?lit"..#litList..") ^\n"

		elseif ast["tag"] == tag["litString"] or ast["tag"] == tag["number"] then
			table.insert(litList, ast[1])
			retAnt = retAnt.."hasDescription(?lit"..#litList..", dLit"..#litList..") ^\n"
			retAnt = retAnt.."swrlb:contains(?desc, ?dLit"..#litList..") ^\n"
			retAnt = retAnt.."swrlx:makeOWLThing(?lit"..#litList..", ?simple"..#operList..") ^\n"

			retCon = retCon.."Literal(?lit"..#litList..") ^\n"
			retCon = retCon.."componentOf(?lit"..#litList..", ?simple"..#expList..") ^\n"
			retCon = retCon.."ExpressionObject(?lit"..#litList..") ^\n"

		-- TODO demais nós
		else
			for _, v in ipairs(ast) do
				if type(v) == "table" then
					retAntAux, retConAux = scanAST(v)
					retAnt = retAnt..retAntAux
					retCon = retCon..retConAux
				end
			end
		end
	end
	return retAnt, retCon
end

-- Função que percorre a AST até achar um WHERE, indicando que devemos começar a gerar a regra SWRL.
local function reachWhere(ast)
	-- Parte do antecedente da saída
	local retAnt = ""
	-- Parte do consequente da saída
	local retCon = ""

	-- Auxiliares
	local retAntAux, retConAux

	assert(type(ast) == "table", "AST não é uma tabela Lua.")

	if ast["tag"] ~= nil then

		if ast["tag"] == tag["where"] then
			if findOr(ast[1]) then
				-- Arrumando o nó de expressão para DNF.
				ast[1] = levelLogicalOperators(turnToDNF(ast[1]))

				-- Cria uma regra para cada cláusula do Or
				for i, v in ipairs(ast[1]) do
					currOr = currOr + 1
					retAnt = retAnt.."Predicate(?pred) ^\n"
					retAnt = retAnt.."hasDescription(?pred, ?desc) ^\n"

					if i == 1 then
						retAnt = retAnt.."swrlb:substringBefore(?or"..(currOr-1)..", ?desc, \" "..tag["or"].." \") ^\n"
					else -- i > 1
						retAnt = retAnt.."swrlb:substringAfter(?or1, ?desc, \" "..tag["or"].." \") ^\n"
						for j=2,(i-1) do
							retAnt = retAnt.."swrlb:substringAfter(?or"..j..", ?or"..(j-1)..", \" "..tag["or"].." \") ^\n"
						end
						retAnt = retAnt.."swrlb:substringBefore(?or0, ?or"..(currOr-1)..", \" "..tag["or"].." \") ^\n"
					end

					retAntAux, retConAux = scanAST(v)
					retAnt = retAnt..retAntAux
					retCon = retCon..retConAux
					table.insert(rules, retAnt:sub(1, -4).."\n-> "..retCon:sub(1, -4))
					idList = {}
					litList = {}
					expList = {}
					operList = {}
					currAnd = 0
					retAnt = ""
					retCon = ""
				end

			else -- Não foi encontrado OR; gera-se apenas uma regra.
				retAnt = retAnt.."Predicate(?pred) ^\n"
				--retAnt = retAnt.."hasDescription(?pred, \""..formDescription(ast).."\") ^\n"
				retAnt = retAnt.."hasDescription(?pred, ?desc) ^\n"
				retAnt = retAnt.."swrlb:substringBefore(?and"..currAnd..", ?desc, \" "..tag["and"].." \") ^\n"
				retAnt = retAnt.."swrlb:substringBefore(?or"..currOr..", ?and"..currAnd..", \" "..tag["or"].." \") ^\n"

				retAntAux, retConAux = scanAST(ast[1])
				retAnt = retAnt..retAntAux
				retCon = retCon..retConAux
				table.insert(rules, retAnt:sub(1, -4).."\n-> "..retCon:sub(1, -4))
			end

		-- Casos de nós da AST que não são o WHERE de SQL.
		else
			for _, v in ipairs(ast) do
				if type(v) == "table" then
					reachWhere(v)
				end
			end
		end
	end
end

-- Zera as listas auxiliares do módulo e reseta variáveis globais
local function resetModule()
	idList = {}
	litList = {}
	expList = {}
	operList = {}
	currAnd = 0
	currOr = 0
	rules = {}
end

-- Função que cria um arquivo cujo conteúdo é a string passada por parâmetro, indexando de
-- acordo com o parâmetro passado. O formato do nome é "query_i.swrl"
-- cond pode ser "w" para um arquivo a ser escrito do zero ou "a" para fazer append.
-- Utilizamos append para o caso de haver um Or, que requer várias regras juntas
local function writeToFile(text, i, cond)
	local file = assert(io.open("Output/query_"..i..".swrl", cond))
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
	reachWhere(ast)

	for i, v in ipairs(rules) do
		local cond
		-- O inicial deve simplesmente escrever no arquivo. Os demais fazem append.
		if i == 1 then
			cond = "w"
		else
			cond = "a"
		end

		writeToFile(v, index, cond)

		if i < #rules then
			writeToFile("\n\n", index, "a")
		end
	end

	resetModule()
end
