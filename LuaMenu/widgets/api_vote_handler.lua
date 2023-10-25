--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
	return {
		name      = "Vote Handler",
		desc      = "Handles spads votes.",
		author    = "Fireball",
		date      = "2023-10-18",
		license   = "GPL-v2",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

local vProps = {
    "source",
    "user",
    "expireTime",
    "awayVoteTime",
    "command",    -- first 5 define the vote
    
    "awayVoters", -- others reflect the current vote status
    "blankCount",
    "manualVoters",
    "noCount",
    "remainingVoters",
    "yesCount",
    -- "voteResult", -- only exists in voteStop
}




local function IsValidVoteUpdate(state)
    for _, key in pairs(vProps) do
        if not state[key] then
            return false
        end
    end
    return true
end

local function IsValidVoteStop(state)
    return IsValidVoteUpdate(state) and state["voteResult"]
end

local function CalcId(state)
    local vote = ""
    for i = 1, 4 do
        vote = vote .. state[vProps[i]]
    end
    for _, cmdPart in pairs(state[vProps[5]]) do
        vote = vote .. cmdPart
    end
    return VFS.CalculateHash(vote, 0)
end

local function EndVote(battleID, voteID)
    lobby:_OnEndVote(battleID, ID)
end

local function AddVote(battleID, voteID, vote)
    if lobby.currentVote then
        EndVote(battleID, lobby.currentVote.id)
    end

    lobby:_OnAddVote(battleID, voteID, vote)
end

-- compare 2 tables and returns diff
local function getDiff(origin, update)
	local diff = {}
	local changed = false
	for uKey, uVal in pairs(update) do
		local changedSub = false
		local oVal = origin[uKey]
		
		if type(uVal) == "table" then
			if type(oVal) == "table" then -- use recursion if value is table and key exists in origin table
				_, changedSub = getDiff(oVal, uVal)
			else
				changedSub = true
			end
		else
			changedSub = uVal ~= oVal
		end

		if changedSub then
            diff[uKey] = uVal
		end
		changed = changed or changedSub
	end
	return diff, changed
end


local function OnPreUpdateVote(listener, battleID, newState)
    Spring.Echo("VH: OnPreUpdateVote", battleID)
    local Config = WG.Chobby.Configuration

    if not IsValidVoteUpdate(newState) then
        Spring.Echo("VH: not valid newState")
        return
    end

    local voteID = CalcId(newState)
    local battle = lobby:GetBattle(battleID)
    local vote = battle.votes[voteID]
    
    if not vote then
        Spring.Echo("VH: recognized new vote")
        newState["id"] = voteID
        newState["battleID"] = battleID
        newState["voteresult"] = Config.VOTE_PENDING
        AddVote(battleID, newState)
        return
    end

    Spring.Echo("VH: recognized existing vote")
    local voteDiff, changed = getDiff(vote, newState)
    if changed then
        lobby:_OnUpdateVote(battleID, voteID, voteDiff)
    end
end

local function OnPreEndVote(listener, battleID, state)
    if not IsValidVoteStop(state) then
        return
    end

    local id = CalcId(state)

end

local function OnCancelVote(listener, battleID)

end

function widget:Update()

end

function widget:Initialize()
	CHOBBY_DIR = LUA_DIRNAME .. "widgets/chobby/"
	VFS.Include(LUA_DIRNAME .. "widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)

    lobby:AddListener("OnPreStartVote",  OnPreUpdateVote)
    lobby:AddListener("OnPreUpdateVote", OnPreUpdateVote)
    lobby:AddListener("OnPreEndStop",   OnPreEndVote)
    lobby:AddListener("OnLeftBattle", OnCancelVote)


end

function widget:Shutdown()
    lobby:RemoveListener("OnPreVoteStart",  OnPreUpdateVote)
    lobby:RemoveListener("OnPreUpdateVote", OnPreUpdateVote)
    lobby:RemoveListener("OnPreEndStop",   OnPreEndVote)
    lobby:RemoveListener("OnLeftBattle",   OnCancelVote)
end