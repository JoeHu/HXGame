--[[
Copyright (c) 2013 crosslife <hustgeziyang@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

--require("Script/Scene/MainMenuScene")
--require("Script/Scene/GameScene")
--require "AudioEngine"

local visibleSize = CCDirector:getInstance():getVisibleSize()

local function createEyeSprite()
    local eyeSprite = CCSprite:create("eye.png")

    local arrayOfActions = CCArray:create()
    local scale1 = CCScaleTo:create(0.1, 1, 0.2)
    local scale2 = CCScaleTo:create(0.1, 1, 1)
    local delay = CCDelayTime:create(2)

    arrayOfActions:addObject(scale1)
    arrayOfActions:addObject(scale2)
    arrayOfActions:addObject(delay)

    local sequence = CCSequence:create(arrayOfActions)

    local repeatFunc = CCRepeatForever:create(sequence)
    eyeSprite:runAction(repeatFunc)

    return eyeSprite
end

local function createPressScreenInfo()
    local testLabel = CCLabelTTF:create("Press Screen", "Arial", 30)
    local arrayOfActions = CCArray:create()
    local scale1 = CCScaleTo:create(1.5, 1.2)
    local scale2 = CCScaleTo:create(1.5, 1)

    arrayOfActions:addObject(scale1)
    arrayOfActions:addObject(scale2)

    local sequence = CCSequence:create(arrayOfActions)

    local repeatFunc = CCRepeatForever:create(sequence)
    testLabel:runAction(repeatFunc)

    testLabel:setPosition(CCPoint(visibleSize.width / 2, 130))

    return testLabel
end

local function createBackLayer()

    local backLayer = CCLayer:create()

    local splashSprite = CCSprite:create("splash_bg.png")
    splashSprite:setPosition(splashSprite:getContentSize().width / 2, splashSprite:getContentSize().height / 2)


    backLayer:addChild(splashSprite)

    local testLabel = createPressScreenInfo()
    backLayer:addChild(testLabel)

    -- handing touch events
    local touchBeginPoint = nil

    local function onTouchBegan(x, y)
        CCLuaLog("touch began...")
        --CCDirector:getInstance():replaceScene(CreateGameScene())
        CCDirector:getInstance():replaceScene(CreateMenuScene())
        touchBeginPoint = {x = x, y = y}
        -- CCTOUCHBEGAN event must return true
        return true
    end

    local function onTouch(eventType, x, y)
        if eventType == "began" then
            return onTouchBegan(x, y)
        end
    end

    backLayer:registerScriptTouchHandler(onTouch)
    backLayer:setTouchEnabled(true)

    return backLayer
end

-- create main menu
function CreateSplashScene()

    local scene = CCScene:create()
    scene:addChild(createBackLayer())

    AudioEngine.playMusic("music/login.wav", true)

    local eyeSprite1 = createEyeSprite()
    eyeSprite1:setPosition(CCPoint(GBackGroundMiddlePoint.x - 50, GBackGroundMiddlePoint.y + 180))
    CCLuaLog("GBackGroundMiddlePoint  "..GBackGroundMiddlePoint.x.."  "..GBackGroundMiddlePoint.y)

    local eyeSprite2 = createEyeSprite()
    eyeSprite2:setPosition(CCPoint(GBackGroundMiddlePoint.x + 50, GBackGroundMiddlePoint.y + 180))

    scene:addChild(eyeSprite1)
    scene:addChild(eyeSprite2)

    return scene
end
