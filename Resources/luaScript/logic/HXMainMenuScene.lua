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

--require("Script/Scene/GameScene")


local visibleSize = CCDirector:getInstance():getVisibleSize()
local function createBackLayer()
    local backLayer = CCLayer:create()

    local menuSprite = CCSprite:create("menu_bg.png")

    menuSprite:setPosition(menuSprite:getContentSize().width / 2, menuSprite:getContentSize().height / 2)

    backLayer:addChild(menuSprite)

    local function onTouchBegan(x, y)
        CCLuaLog("touch began...")
        -- CCDirector:getInstance():replaceScene(CreateGameScene())
        -- CCTOUCHBEGAN event must return true
        return true
    end

    local function onTouch(eventType, x, y)
        if eventType == "began" then
            return onTouchBegan(x, y)
        end
    end

    local function menuStartGame(sender)
        CCLuaLog("Start")
        CCDirector:getInstance():replaceScene(CreateGameScene())
    end
    local function menuExitGame(sender)
        CCLuaLog("Exit")
        HXEngine:getInstance():exitGame()
    end

    CCMenuItemFont:setFontName("Marker Felt")
    local item = CCMenuItemFont:create("Start Game")
    item:setFontSizeObj(40)
    item:registerScriptTapHandler(menuStartGame)
    item:setColor( Color3B(0,200,255) )

    local itemExit = CCMenuItemFont:create("Exit Game")
    itemExit:setFontSizeObj(40)
    itemExit:registerScriptTapHandler(menuStartGame)
    itemExit:setColor( Color3B(0,200,255) )

    local menu = CCMenu:create()
    menu:setPosition(CCPoint(visibleSize.width / 2, visibleSize.height/2))
    menu:addChild(item)
    menu:addChild(itemExit)

    local x,y = item:getPosition()
    itemExit:setPosition(x,y-100)
    itemExit:registerScriptTapHandler(menuExitGame)
    backLayer:addChild(menu)

    backLayer:registerScriptTouchHandler(onTouch)
    backLayer:setTouchEnabled(true)

    return backLayer
end

-- create main menu
function CreateMenuScene()

    local scene = CCScene:create()
    scene:addChild(createBackLayer())

    return scene
end
