print("NPC follower script starting")

local npc = script.Parent
print("NPC:", npc)

local humanoid = npc:FindFirstChild("Humanoid")
print("Humanoid:", humanoid)

local hrp = npc:FindFirstChild("HumanoidRootPart")
print("HumanoidRootPart:", hrp)

local clickDetector = npc:FindFirstChildOfClass("ClickDetector")
print("ClickDetector:", clickDetector)

local animator = humanoid:FindFirstChildOfClass("Animator")
print("Animator:", animator)

local idleAnim = Instance.new("Animation")
idleAnim.AnimationId = "rbxassetid://70743560326921"
print("Idle animation ID:", idleAnim.AnimationId)

local walkAnim = Instance.new("Animation")
walkAnim.AnimationId = "rbxassetid://122322774438996"
print("Walk animation ID:", walkAnim.AnimationId)

local idleTrack = animator:LoadAnimation(idleAnim)
print("IdleTrack loaded:", idleTrack)

local walkTrack = animator:LoadAnimation(walkAnim)
print("WalkTrack loaded:", walkTrack)

idleTrack:Play()
print("Idle animation playing")

local clicked = false
local player = nil

clickDetector.MouseClick:Connect(function(plr)
	print("NPC clicked by:", plr)
	clicked = true
	player = plr
end)

local runService = game:GetService("RunService")
local normalSpeed = humanoid.WalkSpeed
local lastLookVector = nil
local lastPos = nil
local idleTime = 0
local wandering = false
local wanderEnd = 0
local wanderDirection = nil

local function startWander()
	wandering = true
	wanderEnd = tick() + math.random(1,2)
	wanderDirection = Vector3.new(math.random(-10,10),0,math.random(-10,10)).Unit
	print("Wander mode started, ending at:", wanderEnd, "Direction:", wanderDirection)
end

local function stopWander()
	if wandering then
		print("Wander mode stopped")
	end
	wandering = false
	wanderDirection = nil
end

runService.Heartbeat:Connect(function(dt)
	if not clicked then
		print("Waiting for click")
		return
	end

	if not player then
		print("Player missing")
		return
	end

	local char = player.Character
	if not char then
		print("Player character missing")
		return
	end

	local charHRP = char:FindFirstChild("HumanoidRootPart")
	if not charHRP then
		print("Player HRP missing")
		return
	end

	local currentLook = charHRP.CFrame.LookVector
	if not lastLookVector then
		lastLookVector = currentLook
	end

	local turningSpeed = (currentLook - lastLookVector).Magnitude
	lastLookVector = currentLook

	local currentPos = charHRP.Position
	if not lastPos then
		lastPos = currentPos
	end

	local movementSpeed = (currentPos - lastPos).Magnitude
	lastPos = currentPos

	if movementSpeed < 0.05 and turningSpeed < 0.05 then
		idleTime += dt
	else
		if wandering then
			print("Player moved, teleporting NPC back")
			local snapPos = charHRP.Position - (charHRP.CFrame.LookVector * 5)
			hrp.CFrame = CFrame.new(snapPos, charHRP.Position)
		end
		idleTime = 0
		stopWander()
	end

	print("MovementSpeed:", movementSpeed, "TurningSpeed:", turningSpeed, "IdleTime:", idleTime)

	if idleTime >= 5 and not wandering then
		startWander()
	end

	if wandering then
		if tick() >= wanderEnd then
			startWander()
		end
		local wanderTarget = hrp.Position + wanderDirection * 4
		print("Wandering to:", wanderTarget)
		if idleTrack.IsPlaying then idleTrack:Stop() end
		if not walkTrack.IsPlaying then walkTrack:Play() end
		humanoid.WalkSpeed = normalSpeed
		humanoid:MoveTo(wanderTarget)
		return
	end

	local stopDistance = turningSpeed > 0.05 and 1 or 5
	print("StopDistance:", stopDistance)

	local targetPos = charHRP.Position - (charHRP.CFrame.LookVector * stopDistance)
	local distance = (hrp.Position - targetPos).Magnitude

	print("TargetPos:", targetPos, "Distance:", distance)

	if distance > stopDistance then
		if humanoid.WalkSpeed == 0 then
			humanoid.WalkSpeed = normalSpeed
			print("WalkSpeed restored:", normalSpeed)
		end
		if idleTrack.IsPlaying then
			idleTrack:Stop()
			print("Idle stopped")
		end
		if not walkTrack.IsPlaying then
			walkTrack:Play()
			print("Walk playing")
		end
		humanoid:MoveTo(targetPos)
		print("MoveTo called:", targetPos)
	else
		if walkTrack.IsPlaying then
			walkTrack:Stop()
			print("Walk stopped")
		end
		if not idleTrack.IsPlaying then
			idleTrack:Play()
			print("Idle playing")
		end
		humanoid.WalkSpeed = 0
		print("WalkSpeed set to 0 for instant stop")
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		print("Velocity zero, NPC stopped")
	end
end)

