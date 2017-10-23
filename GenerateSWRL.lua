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

-- TODO criar lista de identificadores
-- TODO lista de operadores
-- TODO ver quais outras listas deverão ser criadas

-- Tags para a AST.
local tag = ConstantsForParsing.getTag()

-------------------------------------------------------------------------------------------
-- Funções locais auxiliares ao módulo
-------------------------------------------------------------------------------------------

-- Função que percorre a AST preenchendo a string de saída com o código SWRL de acordo.
local function scanAST(ast)
	local ret = ""

	assert(type(ast) == "table", "AST não é uma tabela Lua.")

	if ast["tag"] ~= nil then

		if ast["tag"] == tag["where"] then
			ret = ret..scanAST(ast[1])
		elseif ast["tag"] == tag["or"] then
			ret = ret..writeOr(ast)
		elseif ast["tag"] == tag["and"] then
			ret = ret..writeAnd(ast)
		elseif ast["tag"] == tag["comp"] then
			ret = ret..writeComp(ast)
		elseif ast["tag"] == tag["mult"] then

		elseif ast["tag"] == tag["add"] then

		elseif ast["tag"] == tag["colId"] then

		elseif ast["tag"] == tag["in"] then

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
Conceitos:
SimpleExpression
ExpressionObject
Literal
ReferencedColumn
ComponentOf (ComparisonOperator, Literal e ReferencedColumn)


--Predicate hasDescription “l_shipdate <= date ’1998-12-01 ’ - interval ’ 87 days ’”
--Column hasName “l_shipdate”
--ComparisonOperator hasDescription “<=”

Conceitos: SimpleExpression, ExpressionObject, Literal, ReferencedColumn e
o relacionamento ComponentOf da SimpleExpression para todos os ExpressionObject
(ComparisonOperator, Literal e ReferencedColumn).

Conclusão que deve ser extraída:

SimpleExpression hasDescription “l_shipdate <= date ’1998-12-01 ’ - interval ’ 87 days ’”

ExpressionObject: “l_shipdate”, “<=”, “date ’1998-12-01 ’ - interval ’ 87 days ’”
(Aqui, pode classificar nas especializações primeiro e depois dizer que também é desse tipo.
 ComparisonOperator já existe, só precisa relacionar com a SimpleExpression)

Literal hasDescription “date ’1998-12-01 ’ - interval ’ 87 days ’”

ReferencedColumn: Column hasName “l_shipdate” (Aqui é só classificar um objeto existente,
 coluna que tenha esse nome)

ComparisonOperator hasDescription “<=” ComponentOf
SimpleExpression hasDescription “l_shipdate <= date ’1998-12-01 ’ - interval ’ 87 days ’”

Literal hasDescription “date ’1998-12-01 ’ - interval ’ 87 days ’”
ComponentOf SimpleExpression hasDescription “l_shipdate <= date ’1998-12-01 ’ - interval ’ 87 days ’”

ReferencedColumn hasName “l_shipdate” ComponentOf
SimpleExpression hasDescription “l_shipdate <= date ’1998-12-01 ’ - interval ’ 87 days ’”

]]