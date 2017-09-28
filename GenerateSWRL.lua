-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
-- Arquivo: GenerateSWRL.lua
-- Autor: Bernardo Pinto de Alkmim (bpalkmim@gmail.com)
--
-- Módulo que gera código SWRL partindo de uma AST de SQL.
-- É necessário ter o pacote lpeg. Recomendo a instalação via Luarocks.
-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

-- Define o módulo.
GenerateSWRL = {}