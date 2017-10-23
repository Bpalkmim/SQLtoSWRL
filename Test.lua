-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
-- Arquivo: Test.lua
-- Autor: Bernardo Alkmim (bpalkmim@gmail.com)
--
-- Um módulo Lua para testar o parser SQL.
-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

require "ParseSQL"

local numTestFiles = 14
local ast = {}

for i = 1, numTestFiles do
	ast[i] = ParseSQL.parseInput("Test/test"..i..".sql")
	print(i.." feito.")
end

for i = 1, #ast do
	print("Imprimindo AST do exemplo "..i..":")
	print(ParseSQL.printAST(ast[i]))
end