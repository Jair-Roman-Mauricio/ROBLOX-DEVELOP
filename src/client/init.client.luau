--!strict
-- Entrada del cliente: ambiente visual, efectos animados e interfaz.

if workspace:GetAttribute("SelvaProcedural") ~= true then
	return
end

require(script.Ambiente).iniciar()
require(script.Efectos).iniciar()
require(script.Interfaz).iniciar()
require(script.Cinematica).iniciar()
