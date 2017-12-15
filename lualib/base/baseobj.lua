local skynet = require "skynet"
local timer = require "base.timer"

CBaseObj = {}
CBaseObj.__index = CBaseObj

function CBaseObj:New()
    local o = setmetatable({}, self)
    o.m_mData = {}
    o.m_mInfo = {}
    o.m_oTimer = timer.NewTimer()
    o.m_bDirty = false
    return o
end

function CBaseObj:Release()
    self.m_oTimer:Release()
    self.m_mData = {}
    self.m_mInfo = {}
end

function CBaseObj:GetData(k, default)
    return self.m_mData[k] or defalut
end

function CBaseObj:SetData(k, v)
    self.m_mData[k] = v
end

function CBaseObj:GetInfo(k, default)
    return self.m_mInfo[k] or default
end

function CBaseObj:SetInfo(k, v)
    self.m_mInfo[k] = v
end

function CBaseObj:IsDirty()
    return self.m_bDirty
end

function CBaseObj:Dirty()
    self.m_bDirty = true
end

function CBaseObj:UnDirty()
    self.m_bDirty = false
end

function CBaseObj:AddTimeCb(sKey, iDelay, func)
    assert(iDelay > 0)
    self.m_oTimer:AddTimeCb(sKey, iDelay, func)
end

function CBaseObj:DelTimeCb(sKey)
    self.m_oTimer:DelTimeCb(sKey)
end


