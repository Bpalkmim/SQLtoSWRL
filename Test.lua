-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
-- Arquivo: Test.lua
-- Autor: Bernardo Alkmim (bpalkmim@gmail.com)
--
-- Um módulo Lua para testar o parser SQL.
-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

require "GenerateSWRL"

local numTestFiles = 14
local ast = {}

--for i = 1, numTestFiles do
--	ast[i] = ParseSQL.parseInput("Test/test"..i..".sql")
--	print(i.." feito.")
--end

--for i = 1, #ast do
--	print("Imprimindo AST do exemplo "..i..":")
--	print(ParseSQL.printAST(ast[i]))
--end

for i = 1, numTestFiles do
	print("Gerando saída do exemplo "..i.."...")
	GenerateSWRL.generateOutput("Test/test"..i..".sql", i)
	print(i.." gerado.\n")
end