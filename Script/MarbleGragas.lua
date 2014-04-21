--[[           
==============================================================================================
                                   Marble Gragas Script 
==============================================================================================
	Changelog:
		1.10:
			-Fix auto update
			-Fix bug barrel that won't explore when using gragas with other skin - thanks to  ilikeman
		1.07:
			-Fix bug barrel sometime don't cast
		1.06:
			-Fixed cast Q in combo
			-Tweaked Q and E spell
		1.05:
			-Added logic for barrel explore.
			-Fixed PullR sometime cast too far from enemy.
	 
]]--

if myHero.charName ~= "Gragas" then return end
local version = 1.11
local AUTOUPDATE = true
local SCRIPT_NAME = "MarbleGragas"
 
-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------

local SOURCELIB_URL = "https://raw.github.com/TheRealSource/public/master/common/SourceLib.lua"
local SOURCELIB_PATH = LIB_PATH.."SourceLib.lua"

if FileExist(SOURCELIB_PATH) then
	require("SourceLib")
else
	DOWNLOADING_SOURCELIB = true
	DownloadFile(SOURCELIB_URL, SOURCELIB_PATH, function() print("Required libraries downloaded successfully, please reload") end)
end

if DOWNLOADING_SOURCELIB then print("Downloading required libraries, please wait...") return end

if AUTOUPDATE then
	 SourceUpdater(SCRIPT_NAME, version, "raw.github.com", "/manasoul/Marble/master/Script/"..SCRIPT_NAME..".lua", SCRIPT_PATH .. GetCurrentEnv().FILE_NAME, "/manasoul/Marble/master/Version/"..SCRIPT_NAME..".version"):CheckUpdate()
end

local RequireI = Require("SourceLib")
RequireI:Add("VPrediction", "https://raw.github.com/honda7/BoL/master/Common/VPrediction.lua")
RequireI:Add("SOW", "https://raw.github.com/honda7/BoL/master/Common/SOW.lua")
RequireI:Check()

if RequireI.downloadNeeded == true then return end

-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
local barrel = nil	
local barrelmis = nil
local barrelTime = 0

--Spell data
local Ranges = {[_Q] = 775 + 75,[_W] = 0, [_E] = 650 + 43, [_R] = 1050}
local Delays = {[_Q] = 0.25, [_E] = 0, [_R] = 0.5}
local Widths = {[_Q] = 300, [_E] = 93, [_R] = 375}
local Speeds = {[_Q] = 1000, [_E] = 2800, [_R] = 2000}

local LastR = 0


--Combo data
local MainCombo = {ItemManager:GetItem("DFG"):GetId(), _Q, _W, _E, _R, _IGNITE}
local cMainCombo = {ItemManager:GetItem("DFG"):GetId(), _Qc, _Wc, _Ec, _Rc, _IGNITE}

function Init()
	VP = VPrediction()
	SOWi = SOW(VP)
	STS = SimpleTS(STS_PRIORITY_LESS_CAST_MAGIC)
	DLib = DamageLib()
	DManager = DrawManager()
	
	Q = Spell(_Q,Ranges[_Q],true)
	E = Spell(_E,Ranges[_E],true)
	R = Spell(_R,Ranges[_R],true)
	W = Spell(_W,Ranges[_W],true)
	
	Q:SetSkillshot(VP,SKILLSHOT_CIRCULAR,Widths[_Q],Delays[_Q],Speeds[_Q],false)
	E:SetSkillshot(VP,SKILLSHOT_LINEAR,Widths[_E],Delays[_E],Speeds[_E],true)
	R:SetSkillshot(VP,SKILLSHOT_LINEAR ,Widths[_R],Delays[_R],Speeds[_R],false)
	Q:SetAOE(true,Q.width,0)
	R:SetAOE(true,R.width,0)
	
	DLib:RegisterDamageSource(_Q,_MAGIC,40,40,_MAGIC,_AP,0.6,function() return (player:CanUseSpell(_Q) == READY) end)
	DLib:RegisterDamageSource(_W,_MAGIC,-10,30,_MAGIC,_AP,0.3,function() return (player:CanUseSpell(_W) == READY) end,function(target) return ((GetDistance(target) <= 600 and player:CanUseSpell(_E) == READY) or GetDistance(target) < 300) and (target.maxHealth * (8 + myHero:GetSpellData(_W).level)/100) or 0 end )
	DLib:RegisterDamageSource(_E,_MAGIC,30,50,_MAGIC,_AP,0.6,function() return (player:CanUseSpell(_E) == READY) end)
	DLib:RegisterDamageSource(_R,_MAGIC,100,100,_MAGIC,_AP,0.7,function() return (player:CanUseSpell(_R) == READY) end)
	
	-- Calculate
	_Qc = 12001
	_Wc = 12002
	_Ec = 12003
	_Rc = 12004
	DLib:RegisterDamageSource(_Qc,_MAGIC,40,40,_MAGIC,_AP,0.6,function() return (player:GetSpellData(_E).level > 0) end)
	DLib:RegisterDamageSource(_Wc,_MAGIC,-10,30,_MAGIC,_AP,0.3,function() return (player:GetSpellData(_W).level > 0) end,function(target) return ((GetDistance(target) <= 600 and player:CanUseSpell(_E) == READY) or GetDistance(target) < 300) and (target.maxHealth * (8 + myHero:GetSpellData(_W).level)/100) or 0 end )
	DLib:RegisterDamageSource(_Ec,_MAGIC,30,50,_MAGIC,_AP,0.6,function() return (player:GetSpellData(_E).level > 0) end)
	DLib:RegisterDamageSource(_Rc,_MAGIC,100,100,_MAGIC,_AP,0.7,function() return (player:GetSpellData(_R).level > 0) end)
	
	enemyChamp = {} 
	for i,enemy in ipairs(GetEnemyHeroes()) do
			table.insert(enemyChamp, enemy)
	end
end

function Menu()
	Menu = scriptConfig("MarbleGragas","MarbleGragas")
	
	Menu:addSubMenu("Target selector","STS")
		STS:AddToMenu(Menu.STS)
	
	Menu:addSubMenu("Orbwalking","Orbwalking")
		SOWi:LoadToMenu(Menu.Orbwalking)
		
	Menu:addSubMenu("Combo","Combo")
		Menu.Combo:addParam("UseQ","Use Q in combo",SCRIPT_PARAM_ONOFF,true)
		Menu.Combo:addParam("UseW","Use W in combo",SCRIPT_PARAM_ONOFF,true)
		Menu.Combo:addParam("UseE","Use E in combo",SCRIPT_PARAM_ONOFF,true)
		Menu.Combo:addParam("UseR","Use R in combo",SCRIPT_PARAM_ONOFF,true)
		Menu.Combo:addParam("UseIgnite","Use Ignite in combo",SCRIPT_PARAM_ONOFF,true)
		
	Menu:addSubMenu("KS","KS")
		Menu.KS:addParam("UseQ","Use Q to KS",SCRIPT_PARAM_ONOFF,true)
		Menu.KS:addParam("UseE","Use E to KS",SCRIPT_PARAM_ONOFF,true)
		Menu.KS:addParam("UseR","Use R if killable",SCRIPT_PARAM_ONOFF,true)
		Menu.KS:addParam("UseIgnite","Use Ignite if killable",SCRIPT_PARAM_ONOFF,true)
		
	Menu:addSubMenu("Harass","Harass")
		Menu.Harass:addParam("UseQ","Use Q",SCRIPT_PARAM_ONOFF,true)
		Menu.Harass:addParam("UseE","Use E",SCRIPT_PARAM_ONOFF,false)
	
	Menu:addSubMenu("Misc","Misc")
		Menu.Misc:addParam("AutoQ","Auto Q barrel explore",SCRIPT_PARAM_ONOFF,true)
					
	Menu:addSubMenu("Drawings","Drawings")
	--[[Spell ranges]]
	for spell,range in pairs(Ranges) do
		DManager:CreateCircle(myHero,range,1,{255,255,255,255}):AddToMenu(Menu.Drawings,SpellToString(spell).." Range",true,true,true)
	end
	
	--[[Predicted damage on healthbars]]
	DLib:AddToMenu(Menu.Drawings,MainCombo)
	Menu.Drawings:addParam("DrawKill","Draw Kill Text",SCRIPT_PARAM_ONOFF,false)
	
	Menu:addParam("ComboEnable","Combo Enabled",SCRIPT_PARAM_ONKEYDOWN,false,32)
	Menu:addParam("HarassEnable","Harass Enabled",SCRIPT_PARAM_ONKEYDOWN,false,67)
	Menu:addParam("ManualPull","Manual pull",SCRIPT_PARAM_ONKEYDOWN,false,65)
	
	--Menu:permaShow("ComboEnable")
	--Menu:permaShow("HarassEnable")
	--Menu:permaShow("ManualPull")
	--Menu.Combo:permaShow("UseR")
	--Menu.KS:permaShow("UseIgnite")
	
end

------------------------------------------
------------[[ Cast Spell]]---------------
------------------------------------------
function UseQ(target)
	if target and Q:IsReady() and myHero:GetSpellData(_Q).toggleState == 1 and Menu.Combo.UseQ then
		Q:Cast(target)
	end
end

function UseW(target)
	if target and W:IsReady() and Menu.Combo.UseW then
			W:Cast(target)
	end
end

function UseE(target)
	if target and W:IsReady() and E:IsReady() then
		W:Cast(target)
	end
	if target and E:IsReady() and Menu.Combo.UseE then
			E:Cast(target)
	end
end

function UseR(target)
	if target and R:IsReady() and Menu.Combo.UseR then
		R:Cast(target)
	end
end

function SkillBehind(from,to,radius)
	if from then
		return from + Vector(from.x-to.x, to.y, from.z-to.z):normalized()*(radius)
	end
	return nil
end

function PullR(target,toLocation)
	if target and R:IsReady() and (Menu.Combo.UseR or Menu.ManualPull) then
	local targetPos = R:GetPrediction(target)
	local castPos = SkillBehind(targetPos,toLocation,Widths[_R] - GetDistance(target.minBBox, target.maxBBox)/2 - 20) 
	
	R:Cast(castPos.x,castPos.z)
	end
end

------------------------------------------
--------------[[ Combo ]]-----------------
------------------------------------------
function Combo()
	local Qtarget = STS:GetTarget(Ranges[_Q])
	local Etarget = STS:GetTarget(Ranges[_E])
	local Rtarget = STS:GetTarget(Ranges[_R])
	local Wtarget = STS:GetTarget(300)
	local IgniteTarget = STS:GetTarget(650)
	SOWi:DisableAttacks()
	
	if Qtarget and DLib:IsKillable(Qtarget, MainCombo) then
		ItemManager:CastOffensiveItems(Qtarget)
	end
	
	if Wtarget and not W:IsReady() then
		SOWi:EnableAttacks()
	end

	if Rtarget and R:IsReady() and DLib:IsKillable(Rtarget, {_R}) then
		UseR(Rtarget)
	elseif Rtarget and R:IsReady() and DLib:IsKillable(Rtarget, {_Q,_R}) then
		if Q:IsReady() and Qtarget then
			Q:Cast(Qtarget)
			do R:Cast(Qtarget) end
		end
	elseif Rtarget and R:GetCooldown(true) < 3 and DLib:IsKillable(Rtarget, {_Qc,_Rc,_Ec}) then
		if R:IsReady() and E:IsReady() then
			PullR(Rtarget,myHero)
		else
			UseE(Etarget)
			UseW(Wtarget)
		end
	elseif Rtarget and R:GetCooldown(true) < 3 and DLib:IsKillable(Rtarget, MainCombo) then
		if R:IsReady() and E:IsReady() then
			PullR(Rtarget,myHero)
		else
			if IgniteTarget and _IGNITE and myHero:CanUseSpell(_IGNITE) == READY and Menu.Combo.UseIgnite then
				CastSpell(_IGNITE, IgniteTarget)
			end
			UseE(Etarget)
			UseW(Wtarget)
		end
	else
		if (GetGameTimer() - LastR) > 0.8 then
				UseQ(Qtarget)
		end
		UseE(Etarget)
		UseW(Wtarget)
	end
	
end

------------------------------------------
--------------[[ Harass ]]----------------
------------------------------------------
function Harass()
	local Qtarget = STS:GetTarget(Ranges[_Q])
	local Etarget = STS:GetTarget(Ranges[_E])

	if Qtarget and Q:IsReady() and myHero:GetSpellData(_Q).toggleState == 1 and Menu.Harass.UseQ then
		Q:Cast(Qtarget)
	end
	
	if Etarget and E:IsReady() and Menu.Harass.UseE then
		E:Cast(Etarget)
	end
end

------------------------------------------
--------------[[ KS ]]----------------
------------------------------------------
function KS()
	local Qtarget = STS:GetTarget(Ranges[_Q])
	local Etarget = STS:GetTarget(Ranges[_E])
	local Rtarget = STS:GetTarget(Ranges[_R])
	local IgniteTarget = STS:GetTarget(650)
	
	if Qtarget and Q:IsReady() and DLib:IsKillable(Qtarget, {_Q}) and Menu.KS.UseQ then
		Q:Cast(Qtarget)
	end
	
	if Etarget and E:IsReady() and DLib:IsKillable(Etarget, {_E}) and Menu.KS.UseE then
		E:Cast(Etarget)
	end
	
	if Rtarget and R:IsReady() and DLib:IsKillable(Rtarget, {_R}) and Menu.KS.UseR then
		R:Cast(Rtarget)
	end
	
	if IgniteTarget and DLib:IsKillable(Rtarget, {_IGNITE}) and _IGNITE and myHero:CanUseSpell(_IGNITE) == READY and Menu.KS.UseIgnite then
		CastSpell(_IGNITE, IgniteTarget)
	end
end

------------------------------------------
--------------[[ Misc ]]------------------
------------------------------------------
function AutoQExplore()
	if Menu.Misc.AutoQ then
		for i,enemy in ipairs(enemyChamp) do
			local rangeAllow = Widths[_Q] - 15
			local rangeToPop = Widths[_Q] 
			if ValidTarget(enemy) and barrel and GetDistance(barrel,enemy) <= rangeToPop then
				if not (GetDistance(barrel,enemy) <= rangeAllow - GetDistance(enemy.minBBox, enemy.maxBBox)/2) then
					CastSpell(_Q)
				end
				if DLib:IsKillable(enemy, {_Qc}) or (DLib:CalcSpellDamage(enemy,_Qc) * 1.5 > enemy.health and GetGameTimer() - barrelTime >= 2.1) then CastSpell(_Q) end
				if GetGameTimer() - barrelTime >= 2.1 then CastSpell(_Q)	end
				if not ValidTarget(enemy) then CastSpell(_Q) end
			end
		end
	end
end


------------------------------------------
--------------[[ Event ]]-----------------
------------------------------------------
function OnProcessSpell(unit,spell)
	if unit.isMe and spell.name:lower():find("gragasr") then
		LastR= GetGameTimer()	
	end
end

function OnCreateObj(obj)
	if obj.name:find("Gragas") and obj.name:find("Q_Mis") then barrelmis = obj end
	if obj.name:find("Gragas") and obj.name:find("Q_Ally") then
		barrel = obj
		barrelTime = GetGameTimer()
	end
end

function OnDeleteObj(obj)
	if obj.name:find("Gragas") and obj.name:find("Q_End") then
		barrel = nil
		barrelmis = nil
	end
end

function OnLoad()
	Init()
	Menu()
end

function OnTick()
	AutoQExplore()
	mousePosition = Vector(mousePos.x,mousePos.y,mousePos.z)
	local Rtarget = STS:GetTarget(Ranges[_R])
	SOWi:EnableAttacks()
	
	if Menu.ComboEnable then Combo() end
	if Menu.HarassEnable then Harass() end
	KS()
	if Menu.ManualPull then
		local Rtarget = STS:GetTarget(Ranges[_R])
		if Rtarget then
			PullR(Rtarget,mousePosition)
		end
	end
	
	
end

function OnDraw()
	if Menu.ManualPull then
		DrawCircle(mousePosition.x,mousePosition.y,mousePosition.z,103,ARGB(255,0,255,0))
	end
	
	if Menu.Drawings.DrawKill then		
		for _, enemy in ipairs(enemyChamp) do
			if ValidTarget(enemy) then
				local barPos = WorldToScreen(D3DXVECTOR3(enemy.x, enemy.y, enemy.z))
				local PosX = barPos.x - 35
				local PosY = barPos.y - 50
				if DLib:IsKillable(enemy, {_Qc}) then
					DrawText("Q kill",18,PosX ,PosY ,ARGB(255,0,255,0))	
				elseif DLib:IsKillable(enemy, {_Qc,_Ec}) then
					DrawText("Q+E kill",18,PosX ,PosY ,ARGB(255,0,255,0))	
				elseif DLib:IsKillable(enemy, {_Rc}) then
					DrawText("R kill",18,PosX ,PosY ,ARGB(255,0,255,0))	
				elseif DLib:IsKillable(enemy, {_Qc,_Rc}) then
					DrawText("Q + R kill",18,PosX ,PosY ,ARGB(255,0,255,0))	
				elseif DLib:IsKillable(enemy, {_Qc,_Rc,_Ec}) then
					DrawText("Murder him",18,PosX ,PosY ,ARGB(255,0,255,0))	
				elseif DLib:IsKillable(enemy, {ItemManager:GetItem("DFG"):GetId(), _Qc, _Wc, _Ec, _Rc, _IGNITE}) then
					DrawText("Hard kill",18,PosX ,PosY ,ARGB(255,255,124,0))	
				else
					
					local HealthLeft = math.round(enemy.health - DLib:CalcComboDamage(enemy,{ItemManager:GetItem("DFG"):GetId(), _Qc, _Wc, _Ec, _Rc, _IGNITE}))
					local PctLeft = math.round(HealthLeft / enemy.maxHealth * 100)
					DrawText(PctLeft .. "% Harass",18,PosX ,PosY ,ARGB(255,255,0,0))	
				end
				
			end
		end
		
	end
end
