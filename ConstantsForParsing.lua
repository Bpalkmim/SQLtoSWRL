-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
-- Arquivo: ConstantsForParsing.lua
-- Autor: Bernardo Alkmim (bpalkmim@gmail.com)
--
-- Um módulo Lua que contém constantes úteis tanto para o frontend quanto para o backend.
-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

local lpeg = require "lpeg"

-- Define o módulo
ConstantsForParsing = {}

-- Tags para a AST.
local tag = {}
tag["select"] 		= "SelectionCmd"
tag["from"] 		= "From"
tag["join"] 		= "Join"
tag["where"] 		= "Where"
tag["id"] 			= "Identifier"
tag["root"] 		= "Root"
tag["command"] 		= "Command"
tag["selectStmt"] 	= "Select"
tag["columns"] 		= "Columns"
tag["on"] 			= "On"
tag["using"] 		= "Using"
tag["colId"] 		= "Column ID"
tag["natural"] 		= "Natural"
tag["inner"] 		= "Inner"
tag["left"] 		= "Left"
tag["outer"] 		= "Outer"
tag["cross"] 		= "Cross"
tag["and"] 			= "And"
tag["or"] 			= "Or"
tag["as"] 			= "As"
tag["alias"] 		= "Alias"
tag["orderby"] 		= "Order By"
tag["groupby"] 		= "Group By"
tag["date"] 		= "Date"
tag["interval"] 	= "Interval"
tag["not"] 			= "Not"
tag["function"] 	= "Function"
tag["desc"] 		= "Desc"
tag["between"] 		= "Between"
tag["case"] 		= "Case"
tag["like"]			= "Like"
tag["escape"]		= "Escape"
tag["litString"]	= "LitString"
tag["number"]		= "Number"
tag["limit"]		= "Limit"
tag["all"]			= "All"
tag["offset"]		= "Offset"
tag["having"]		= "Having"
tag["in"]			= "In"
tag["comp"]			= "Comp"
tag["add"]			= "Add"
tag["mult"]			= "Mult"
tag["distinct"]		= "Distinct"

function ConstantsForParsing.getTag()
	return tag
end

-- Palavras-chave.
local kw = {}
kw["as"] 		= lpeg.S("Aa") * lpeg.S("Ss")
kw["in"] 		= lpeg.S("Ii") * lpeg.S("Nn")
kw["on"] 		= lpeg.S("Oo") * lpeg.S("Nn")
kw["or"] 		= lpeg.S("Oo") * lpeg.S("Rr")
kw["all"]		= lpeg.S("Aa") * lpeg.S("Ll") * lpeg.S("Ll")
kw["and"] 		= lpeg.S("Aa") * lpeg.S("Nn") * lpeg.S("Dd")
kw["end"] 		= lpeg.S("Ee") * lpeg.S("Nn") * lpeg.S("Dd")
kw["not"] 		= lpeg.S("Nn") * lpeg.S("Oo") * lpeg.S("Tt")
kw["from"] 		= lpeg.S("Ff") * lpeg.S("Rr") * lpeg.S("Oo") * lpeg.S("Mm")
kw["join"] 		= lpeg.S("Jj") * lpeg.S("Oo") * lpeg.S("Ii") * lpeg.S("Nn")
kw["left"] 		= lpeg.S("Ll") * lpeg.S("Ee") * lpeg.S("Ff") * lpeg.S("Tt")
kw["full"] 		= lpeg.S("Ff") * lpeg.S("Uu") * lpeg.S("Ll") * lpeg.S("Ll")
kw["null"] 		= lpeg.S("Nn") * lpeg.S("Uu") * lpeg.S("Ll") * lpeg.S("Ll")
kw["date"] 		= lpeg.S("Dd") * lpeg.S("Aa") * lpeg.S("Tt") * lpeg.S("Ee")
kw["true"] 		= lpeg.S("Tt") * lpeg.S("Rr") * lpeg.S("Uu") * lpeg.S("Ee")
kw["desc"] 		= lpeg.S("Dd") * lpeg.S("Ee") * lpeg.S("Ss") * lpeg.S("Cc")
kw["case"] 		= lpeg.S("Cc") * lpeg.S("Aa") * lpeg.S("Ss") * lpeg.S("Ee")
kw["when"] 		= lpeg.S("Ww") * lpeg.S("Hh") * lpeg.S("Ee") * lpeg.S("Nn")
kw["then"] 		= lpeg.S("Tt") * lpeg.S("Hh") * lpeg.S("Ee") * lpeg.S("Nn")
kw["else"] 		= lpeg.S("Ee") * lpeg.S("Ll") * lpeg.S("Ss") * lpeg.S("Ee")
kw["like"]		= lpeg.S("Ll") * lpeg.S("Ii") * lpeg.S("Kk") * lpeg.S("Ee")
kw["cross"] 	= lpeg.S("Cc") * lpeg.S("Rr") * lpeg.S("Oo") * lpeg.S("Ss") * lpeg.S("Ss")
kw["limit"]		= lpeg.S("Ll") * lpeg.S("Ii") * lpeg.S("Mm") * lpeg.S("Ii") * lpeg.S("Tt")
kw["outer"] 	= lpeg.S("Oo") * lpeg.S("Uu") * lpeg.S("Tt") * lpeg.S("Ee") * lpeg.S("Rr")
kw["inner"] 	= lpeg.S("Ii") * lpeg.S("Nn") * lpeg.S("Nn") * lpeg.S("Ee") * lpeg.S("Rr")
kw["right"] 	= lpeg.S("Rr") * lpeg.S("Ii") * lpeg.S("Gg") * lpeg.S("Hh") * lpeg.S("Tt")
kw["using"] 	= lpeg.S("Uu") * lpeg.S("Ss") * lpeg.S("Ii") * lpeg.S("Nn") * lpeg.S("Gg")
kw["where"] 	= lpeg.S("Ww") * lpeg.S("Hh") * lpeg.S("Ee") * lpeg.S("Rr") * lpeg.S("Ee")
kw["false"] 	= lpeg.S("Ff") * lpeg.S("Aa") * lpeg.S("Ll") * lpeg.S("Ss") * lpeg.S("Ee")
kw["escape"]	= lpeg.S("Ee") * lpeg.S("Ss") * lpeg.S("Cc") * lpeg.S("Aa") * lpeg.S("Pp") * lpeg.S("Ee")
kw["having"]	= lpeg.S("Hh") * lpeg.S("Aa") * lpeg.S("Vv") * lpeg.S("Ii") * lpeg.S("Nn") * lpeg.S("Gg")
kw["offset"]	= lpeg.S("Oo") * lpeg.S("Ff") * lpeg.S("Ff") * lpeg.S("Ss") * lpeg.S("Ee") * lpeg.S("Tt")
kw["select"] 	= lpeg.S("Ss") * lpeg.S("Ee") * lpeg.S("Ll") * lpeg.S("Ee") * lpeg.S("Cc") * lpeg.S("Tt")
kw["natural"] 	= lpeg.S("Nn") * lpeg.S("Aa") * lpeg.S("Tt") * lpeg.S("Uu") * lpeg.S("Rr") * lpeg.S("Aa") * lpeg.S("Ll")
kw["between"] 	= lpeg.S("Bb") * lpeg.S("Ee") * lpeg.S("Tt") * lpeg.S("Ww") * lpeg.S("Ee") * lpeg.S("Ee") * lpeg.S("Nn")
kw["orderby"] 	=
	lpeg.S("Oo") * lpeg.S("Rr") * lpeg.S("Dd") * lpeg.S("Ee") * lpeg.S("Rr") * lpeg.P(" ") * lpeg.S("Bb") * lpeg.S("Yy")
kw["groupby"] 	=
	lpeg.S("Gg") * lpeg.S("Rr") * lpeg.S("Oo") * lpeg.S("Uu") * lpeg.S("Pp") * lpeg.P(" ") * lpeg.S("Bb") * lpeg.S("Yy")
	kw["distinct"]	=
	lpeg.S("Dd") * lpeg.S("Ii") * lpeg.S("Ss") * lpeg.S("Tt") * lpeg.S("Ii") * lpeg.S("Nn") * lpeg.S("Cc") * lpeg.S("Tt")
kw["interval"] 	=
	lpeg.S("Ii") * lpeg.S("Nn") * lpeg.S("Tt") * lpeg.S("Ee") * lpeg.S("Rr") * lpeg.S("Vv") * lpeg.S("Aa") * lpeg.S("Ll")

function ConstantsForParsing.getKw()
	return kw
end