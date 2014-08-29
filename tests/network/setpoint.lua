-------------------------------------------------------------------------------
-- Setpoint network test.
-- @author Sean
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
require "tests.assertions"

describe("Setpoint #setpoint", function ()
    local net = require "tests.network"
    local timers = require 'rinSystem.rinTimers.Pack'
    local app, upper, lower, death

    setup(function()
        app, upper, lower = net.openDevices()
    end)

    teardown(function()
        net.closeDevices(app)
    end)

    before_each(function()
        death = timers.addTimer(0, 30, function() assert.equal("timed out", nil) end)
    end)

    after_each(function()
        timers.removeTimer(death)
        death = nil
    end)
    
    it("number", function()
        local cb = spy.new(function() end)
        
        finally(function()
            lower.setAllIOCallback(nil)
            upper.setNumSetp(1)
            upper.setpType(1, 'off')
        end)
        
        -- set 8 setpoints to 'on', use IOs 1 through 8
        for i = 1, 8 do
            upper.setpType(i, 'on')
            upper.setpIO(i, i)
        end
        
        lower.setAllIOCallback(cb)
        app.delay(0.3)
        upper.setNumSetp(3)
        app.delay(0.3)
        assert.spy(cb).was.called_with(7)
        upper.setNumSetp(6)
        app.delay(0.3)
        assert.spy(cb).was.called_with(63)
    end)
    
    it("over", function()
        local cb = spy.new(function() end)
        
        finally(function()
            lower.setAllIOCallback(nil)
            upper.setNumSetp(1)
            upper.setpType(1, 'off')
        end)
        
        -- set 4 setpoints to 'over', use IOs 1 through 4
        local targ = 2000
        for i = 1, 4 do
            upper.setpType(i, 'over')
            upper.setpIO(i, i)
            upper.setpTarget(i, targ)
            targ = targ + 2000  -- increment for each setpoint
        end
        upper.setNumSetp(4)
        
        lower.setAnalogVolt(0)
        app.delay(1)
        lower.setAllIOCallback(cb)
        app.delay(0.2)
        lower.setAnalogVolt(10)
        app.delay(0.6)
        assert.spy(cb).was.called_with(1)
        app.delay(0.2)
        assert.spy(cb).was.called_with(3)
        app.delay(0.2)
        assert.spy(cb).was.called_with(7)
        app.delay(0.2)
        assert.spy(cb).was.called_with(15)
        lower.setAnalogVolt(0)
        app.delay(0.6)
        assert.spy(cb).was.called_with(7)
        app.delay(0.2)
        assert.spy(cb).was.called_with(3)
        app.delay(0.2)
        assert.spy(cb).was.called_with(1)
        app.delay(0.2)
        assert.spy(cb).was.called_with(0)
    end)
    
    it("under", function()
        local cb = spy.new(function() end)
        
        finally(function()
            lower.setAllIOCallback(nil)
            upper.setNumSetp(1)
            upper.setpType(1, 'off')
        end)
        
        -- set 4 setpoints to 'under', use IOs 1 through 4
        local targ = 2000
        for i = 1, 4 do
            upper.setpType(i, 'under')
            upper.setpIO(i, i)
            upper.setpTarget(i, targ)
            targ = targ + 2000  -- increment for each setpoint
        end
        upper.setNumSetp(4)
        
        lower.setAnalogVolt(0)
        app.delay(1)
        lower.setAllIOCallback(cb)
        app.delay(0.2)
        lower.setAnalogVolt(10)
        app.delay(0.6)
        assert.spy(cb).was.called_with(14)
        app.delay(0.2)
        assert.spy(cb).was.called_with(12)
        app.delay(0.2)
        assert.spy(cb).was.called_with(8)
        app.delay(0.2)
        assert.spy(cb).was.called_with(0)
        lower.setAnalogVolt(0)
        app.delay(0.6)
        assert.spy(cb).was.called_with(8)
        app.delay(0.2)
        assert.spy(cb).was.called_with(12)
        app.delay(0.2)
        assert.spy(cb).was.called_with(14)
        app.delay(0.2)
        assert.spy(cb).was.called_with(15)
    end)
    
    it("status", function()
        local cb = spy.new(function() end)
        
        finally(function()
            lower.setAllIOCallback(nil)
            upper.setNumSetp(1)
            upper.setpType(1, 'off')
            upper.presetTare(0)
            upper.gross()
        end)
        
        -- set 4 setpoints to use IOs 1 through 4
        for i = 1, 4 do
            upper.setpIO(i, i)
        end
        upper.setNumSetp(4)
        upper.setpType(1, 'coz')
        upper.setpType(2, 'zero')
        upper.setpType(3, 'net')
        upper.setpType(4, 'motion')
        -- skip 'error', 'scale_ready', 'scale_exit' and 'buzzer' for now until we find a good way to test them
        upper.gross()  -- make sure we are starting in gross
        
        lower.setAnalogVolt(2)
        app.delay(1)
        lower.setAllIOCallback(cb)
        app.delay(0.3)
        lower.setAnalogVolt(0)
        app.delay(0.3)
        upper.waitStatus('zero')  -- wait until we are in the zero band
        upper.waitStatus('notmotion')  -- zero wont happen until weight is stable
        upper.zero()  -- perform user zero so we will always get coz
        app.delay(0.3)
        assert.spy(cb).was.called_with(3)
        lower.setAnalogVolt(5)
        app.delay(0.3)
        assert.spy(cb).was.called_with(8)
        upper.presetTare(500)
        upper.net()
        app.delay(0.3)
        assert.spy(cb).was.called_with(12)
        upper.waitStatus('notmotion')
        app.delay(0.3)
        assert.spy(cb).was.called_with(4)
        upper.gross()
        app.delay(0.3)
        assert.spy(cb).was.called_with(0)
    end)
    
    it("logic", function()
        local cb = spy.new(function() end)
        
        finally(function()
            lower.setAllIOCallback(nil)
            upper.setNumSetp(1)
            upper.setpType(1, 'off')
            upper.setpLogic(1, 'high')
            upper.setpLogic(2, 'high')
            upper.setpIO(1, 0)
        end)
        
        -- set 2 setpoints to 'over', use IOs 1 and 2
        local targ = 2000
        for i = 1, 2 do
            upper.setpType(i, 'over')
            upper.setpIO(i, i)
            upper.setpTarget(i, targ)
        end
        upper.setNumSetp(2)
        upper.setpLogic(1, 'high')
        upper.setpLogic(2, 'low')
        
        lower.setAnalogVolt(0)
        app.delay(1)
        lower.setAllIOCallback(cb)
        app.delay(0.2)
        lower.setAnalogVolt(4)
        app.delay(0.8)
        assert.spy(cb).was.called_with(1)
        lower.setAnalogVolt(0)
        app.delay(0.8)
        assert.spy(cb).was.called_with(2)
    end)
    
    it("source", function()
        local cb = spy.new(function() end)
        
        finally(function()
            lower.setAllIOCallback(nil)
            upper.setNumSetp(1)
            upper.setpType(1, 'off')
            upper.setpIO(1, 0)
            upper.setpSource(2, 'gross')
            upper.setpSource(3, 'gross')
            upper.gross()
        end)
        
        -- set 3 setpoints to 'over', use IOs 1 through 3
        local targ = 2000
        for i = 1, 3 do
            upper.setpType(i, 'over')
            upper.setpIO(i, i)
            upper.setpTarget(i, targ)
        end
        upper.setNumSetp(3)
        upper.setpSource(1, 'gross')
        upper.setpSource(2, 'net')
        upper.setpSource(3, 'disp')
        
        lower.setAnalogVolt(0)
        upper.presetTare(2000)
        upper.gross()
        app.delay(1)
        lower.setAllIOCallback(cb)
        app.delay(0.2)
        lower.setAnalogVolt(3)
        app.delay(1)
        assert.spy(cb).was.called_with(5)
        upper.net()
        app.delay(0.2)
        assert.spy(cb).was.called_with(1)
        lower.setAnalogVolt(5)
        app.delay(1)
        assert.spy(cb).was.called_with(7)
    end)
end)
