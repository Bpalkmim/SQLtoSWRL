# SQLtoSWRL
A compiler from SQL to SWRL in Lua using LPeg to generate the AST.

I used Lua version 5.1 and LPeg version 1.0.1.

### Current Status
We only generate queries (SELECT). We do not deal yet with CREATE or DELETE.

### Known bugs
In test case 7, inside the "case" clause, there is an expression inside (redundant) parentheses that makes the program not stop when generating the AST.

This does not happen with redundant parentheses in other cases, so they have been removed in that case for now.

### Using the program
To use it, from the main directory in this repository type in the command line:

``lua Test.lua``

if your version is 5.1, or

``lua5.1 Test.lua``

if newer.

These just run our test cases. If you wish to utilize the program for any other queries you have, just access them via the functions:

``ParseSQL.parseInput(fileName)``

from ``ParseSQL.lua`` to just generate the AST, or

``GenerateSWRL.generateOutput(fileName, index)``

from ``GenerateSWRL.lua``, which uses the previous function to generate the AST and creates a SWRL file.
