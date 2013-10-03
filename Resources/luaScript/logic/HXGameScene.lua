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

--require "Script/Logic/GameBoardLogic"
--require "Script/Sprite/GameIcon"

local scene = nil

local curSelectTag = nil

local NODE_TAG_START = 10000
local NORMAL_TAG = 10
local MATCH_TAG = 30
local SELECT_TAG = 40

local REMOVED_TAG = 20000
local FALLING_TAG = 30000

local isTouching = false
local isMoving = false
local isRefreshing = false

local touchStartPoint = {}
local touchEndPoint = {}

local touchStartCell = {}
local touchEndCell = {}

local succCellSet = {}
local switchCellSet = {}
local fallCellSet = {}

--用于存储执行交换结点
local switchCellPair = {}

--执行各种函数的辅助node
local RefreshBoardNode = nil
local FallEndCheckNode = nil
local ScoreLabel = nil

--闪烁节点
local blinkCell = nil

local visibleSize = CCDirector:getInstance():getVisibleSize()

--根据index创建某类型结点，不包含额外信息
local function createNodeByIndex(index)
    local iconNormalSprite = getGameIconSprite(GIconNormalType, index)
    local iconMatchSprite = getGameIconSprite(GIconMatchType, index)
    local iconSelectSprite = getGameIconSprite(GIconSelectType, index)

    iconNormalSprite:setTag(NORMAL_TAG)
    iconMatchSprite:setTag(MATCH_TAG)
    iconSelectSprite:setTag(SELECT_TAG)

    iconMatchSprite:setVisible(false)
    iconSelectSprite:setVisible(false)

    local iconNode = CCNode:create()
    iconNode:addChild(iconNormalSprite)
    iconNode:addChild(iconMatchSprite)
    iconNode:addChild(iconSelectSprite)

    return iconNode
end

--创建某个位置上的结点图标
local function createNodeByCell(cell)
    local index = GameBoard[cell.x][cell.y]
    local iconNode = createNodeByIndex(index)

    iconNode:setTag(NODE_TAG_START + 10 * cell.x + cell.y)

    local cellPoint = getCellCenterPoint(cell)
    iconNode:setPosition(CCPoint(cellPoint.x, cellPoint.y))

    return iconNode
end

--初始化棋盘图标
local function initGameBoardIcon()
    for x=1, GBoardSizeX do
        for y = 1, GBoardSizeY do
            local iconNode = createNodeByCell({x = x, y = y})
            scene:addChild(iconNode)
        end
    end
end

--重置之前选中棋子的选中状态
local function resetSelectGameIcon()
    if curSelectTag ~= nil then
        local cellNode = scene:getChildByTag(NODE_TAG_START + curSelectTag)
        if cellNode ~= nil then
            local normalSprite = cellNode:getChildByTag(NORMAL_TAG)
            local selectSprite = cellNode:getChildByTag(SELECT_TAG)
            if normalSprite ~= nil then
                normalSprite:setVisible(true)
            end

            if selectSprite ~= nil then
                selectSprite:setVisible(false)
            end
        end
        curSelectTag = nil
    end
end

--点击棋子更换图标效果
local function onClickGameIcon(cell)
    if cell.x == 0 or cell.y == 0 then
        return
    end

    resetSelectGameIcon()

    curSelectTag = 10 * cell.x + cell.y

    scene:getChildByTag(NODE_TAG_START + curSelectTag):getChildByTag(NORMAL_TAG):setVisible(false)
    scene:getChildByTag(NODE_TAG_START + curSelectTag):getChildByTag(SELECT_TAG):setVisible(true)

    AudioEngine.playEffect("effect/A_select.wav")
end

--交换相邻棋子，并执行回调函数(一般为检测是否命中)
local function switchCell(cellA, cellB, cfCallBack)
    --CCLuaLog("switchCell...")
    --CCLuaLog("cellA.."..cellA.x.." "..cellA.y)
    --CCLuaLog("cellB.."..cellB.x.." "..cellB.y)
    isTouching = false

    resetSelectGameIcon()

    local tagA = 10 * cellA.x + cellA.y
    local tagB = 10 * cellB.x + cellB.y

    local cellPointA = getCellCenterPoint(cellA)
    local cellPointB = getCellCenterPoint(cellB)

    local nodeA = scene:getChildByTag(NODE_TAG_START + tagA)
    local nodeB = scene:getChildByTag(NODE_TAG_START + tagB)

    if nodeA == nil or nodeB == nil then
        CCLuaLog("can't find node!!")
        return
    end

    local moveToA = CCMoveTo:create(0.1, CCPoint(cellPointA.x, cellPointA.y))

    --将检测的回调函数绑定在A cell上
    local function moveAWithCallBack()

        local arrayOfActions = CCArray:create()

        local moveToB = CCMoveTo:create(0.1, CCPoint(cellPointB.x, cellPointB.y))
        arrayOfActions:addObject(moveToB)

        if cfCallBack ~= nil then
            --CCLuaLog("move with call back..")
            local callBack = CCCallFunc:create(cfCallBack)
            arrayOfActions:addObject(callBack)
        end

        local sequence = CCSequence:create(arrayOfActions)
        nodeA:runAction(sequence)
    end

    moveAWithCallBack()
    nodeB:runAction(moveToA)

    --swap tag
    nodeA:setTag(NODE_TAG_START + tagB)
    nodeB:setTag(NODE_TAG_START + tagA)

    --swap index
    GameBoard[cellA.x][cellA.y], GameBoard[cellB.x][cellB.y] = GameBoard[cellB.x][cellB.y], GameBoard[cellA.x][cellA.y]
end

--移除格子回调函数
local function cfRemoveSelf(matchSprite)
    --CCLuaLog("cf remove self")
    if matchSprite == nil then
        CCLuaLog("remove failed")
    else
        matchSprite:getParent():removeFromParentAndCleanup(true)
    end
end

--变为匹配图标并渐隐回调
local function cfMatchAndFade(node)
    if node ~= nil then
        local normalSprite = node:getChildByTag(NORMAL_TAG)
        local matchSprite = node:getChildByTag(MATCH_TAG)
        local selectSprite = node:getChildByTag(SELECT_TAG)
        if normalSprite ~= nil then
            normalSprite:setVisible(false)
        end

        if selectSprite ~= nil then
            selectSprite:setVisible(false)
        end

        if matchSprite ~= nil then
            matchSprite:setVisible(true)

            local arrayOfActions = CCArray:create()

            local fade = CCFadeOut:create(0.2)
            local removeFunc = CCCallFunc:create(cfRemoveSelf)

            arrayOfActions:addObject(fade)
            arrayOfActions:addObject(removeFunc)

            local sequence = CCSequence:create(arrayOfActions)

            matchSprite:runAction(sequence)
        end
    end
end

-- 刷新分数
local function updateScore()
    ScoreLabel:setString("Score : "..TotalScore)
end

--将某个集合的格子渐隐并移除
local function removeCellSet(cellSet)
    local count = 0
    for k,v in pairs(cellSet) do
        --CCLuaLog("remove.."..cellSet[i].x.."  "..cellSet[i].y)
        local tag = 10 * v.x + v.y
        local node = scene:getChildByTag(NODE_TAG_START + tag)

        --此时直接清除数据
        node:setTag(REMOVED_TAG + tag)
        GameBoard[v.x][v.y] = 0

        node:runAction(CCCallFunc:create(cfMatchAndFade))
        count = count + 1
    end
    if count>7 then
        scoreConf[count]=scoreConf[7]
        CCLuaLog("为什么会出现大于7的情况呢?不可能的...因为有blink")
    end
    TotalScore = TotalScore + scoreConf[count]
    CCLuaLog("本次得分:"..scoreConf[count])
    CCLuaLog("总得分:"..TotalScore)
    updateScore()
end

--匹配消除后刷新游戏面板
local function cfRefreshBoard()
    --CCLuaLog("cfRefreshBoard..")
    local firstEmptyCell = nil
    local addCellList = nil
    local moveCellList = nil

    firstEmptyCell, addCellList, moveCellList = getRefreshBoardData()

    local actionNodeList = {}
    --遍历每一列
    for i = 1, GBoardSizeX do
        if firstEmptyCell[i] ~= nil then
            --CCLuaLog("firstEmptyCell.."..i..".."..firstEmptyCell[i].x..firstEmptyCell[i].y)
            local nextDesCell = {x = firstEmptyCell[i].x, y = firstEmptyCell[i].y}
            for j = 1, #(moveCellList[i]) do

                local cell = {x = moveCellList[i][j].x, y = moveCellList[i][j].y}
                --CCLuaLog("moveCellList"..i..".."..cell.x..cell.y)
                local tag = 10 * cell.x + cell.y
                local node = scene:getChildByTag(NODE_TAG_START + tag)

                local desTag = 100 * GameBoard[cell.x][cell.y] + 10 * nextDesCell.x + nextDesCell.y
                node:setTag(FALLING_TAG + desTag)

                actionNodeList[#actionNodeList + 1] = {}
                actionNodeList[#actionNodeList][1] = node
                actionNodeList[#actionNodeList][2] = nextDesCell
                nextDesCell = {x = nextDesCell.x, y = nextDesCell.y + 1}
                --local desCell =
            end

            for j = 1, #(addCellList[i]) do
                --CCLuaLog("addCellList"..i..".."..addCellList[i][j])

                local node = createNodeByIndex(addCellList[i][j])
                local bornPoint = getCellCenterPoint({x = i, y = 10})

                node:setPosition(CCPoint(bornPoint.x, bornPoint.y))

                --新加的结点tag中包含自己的index信息
                local desTag = 100 * addCellList[i][j] + 10 * nextDesCell.x + nextDesCell.y
                node:setTag(FALLING_TAG + desTag)
                scene:addChild(node)

                actionNodeList[#actionNodeList + 1] = {}
                actionNodeList[#actionNodeList][1] = node
                actionNodeList[#actionNodeList][2] = nextDesCell
                nextDesCell = {x = nextDesCell.x, y = nextDesCell.y + 1}
            end
        end
    end

    --移动完毕后的回调函数
    local function cfOnFallDownEnd(node)
        --CCLuaLog("fall down end...")
        local tag = node:getTag() - FALLING_TAG
        --CCLuaLog("tag.."..tag)
        local index = math.modf(tag / 100)

        --提取并去除index信息
        tag = tag - index * 100
        local x = math.modf(tag / 10)
        local y = tag % 10

        GameBoard[x][y] = index
        --CCLuaLog("nowTag.."..tag)
        node:setTag(NODE_TAG_START + tag)
    end

    --执行下落到棋盘操作
    for i = 1, #actionNodeList do
        local node = actionNodeList[i][1]
        local desCell = actionNodeList[i][2]
        local desPos = getCellCenterPoint(desCell)
        local desPoint = CCPoint(desPos.x, desPos.y)

        local arrayOfActions = CCArray:create()

        local move = CCMoveTo:create(0.1, desPoint)
        local fallDownEndFunc = CCCallFunc:create(cfOnFallDownEnd)

        arrayOfActions:addObject(move)
        arrayOfActions:addObject(fallDownEndFunc)

        local sequence = CCSequence:create(arrayOfActions)

        node:runAction(sequence)

        --加入下落完成检测集合
        fallCellSet[#fallCellSet + 1] = desCell
    end

    actionNodeList = {}

    --下落后检查是否有新的命中
    --FallEndCheckNode
    local arrayOfActions = CCArray:create()

    local delay = CCDelayTime:create(0.2)
    local fallCheckFunc = CCCallFunc:create(cfCheckFallCell)

    arrayOfActions:addObject(delay)
    arrayOfActions:addObject(fallCheckFunc)

    local sequence = CCSequence:create(arrayOfActions)

    FallEndCheckNode:runAction(sequence)
end

--延迟一段时间后刷新棋盘
local function delayToRefreshBoardNode()
    CCLuaLog("xxxxx1")
    local arrayOfActions = CCArray:create()

    local delay = CCDelayTime:create(0.2)
    local refreshBoardFunc = CCCallFunc:create(cfRefreshBoard)

    arrayOfActions:addObject(delay)
    arrayOfActions:addObject(refreshBoardFunc)

    local sequence = CCSequence:create(arrayOfActions)

    RefreshBoardNode:runAction(sequence)
    CCLuaLog("xxxxx2")
end

local function onCheckSuccess(succCellSet)
    if #succCellSet == 0 then
        return
    end

    --匹配成功
    CCLuaLog("switch success!!!")
    AudioEngine.playEffect("effect/A_combo1.wav")

    --to do: 执行消除，填充棋盘
    --获得邻近格子集合
    local matchCellSet = {}

    --用于检测是否已加入
    for i = 1, #succCellSet do
        local succCell = succCellSet[i].cell
        local succCellRes = succCellSet[i].result
        local matchCellSetTmp = getMatchCellSet(succCell,succCellRes)
        HXUtilMergeSet(matchCellSet,matchCellSetTmp)
    end
    removeCellSet(matchCellSet)
    delayToRefreshBoardNode()
end

-- 点击blink
local function onClickBlinkCell(cell)
    CCLuaLog("点击blink")
    local tag = 10 * cell.x + cell.y
    CCLuaLog("tag="..NODE_TAG_START+tag)
    local node = scene:getChildByTag(NODE_TAG_START + tag)
    local animation = CCAnimationCache:getInstance():animationByName("blinkAnimation")
    local curAnimIdx = 0
    local array = animation:getFrames()
    local n = array:count()-1
    CCLuaLog("n===",n)
    for i=0,n do
        local animFrame = tolua.cast(array:objectAtIndex(i),"CCAnimationFrame")
        local spriteFrame = animFrame:getSpriteFrame()
        CCLuaLog(i,animFrame,node,animFrame:getSpriteFrame())
        if node:isFrameDisplayed(animFrame:getSpriteFrame()) then
        --if node:getTexture():getName()==spriteFrame:getTexture():getName() then
            curAnimIdx = i+1
            break
        end
    end
    CCLuaLog("消除全部=",curAnimIdx)
    local matchCellSet = getMatchCellSetWithBlink(cell,curAnimIdx)
    removeCellSet(matchCellSet)
    delayToRefreshBoardNode()
    node:removeFromParentAndCleanup(true)
end

--创建随机棋子下落到棋盘并改变棋盘数据
local function addBlinkIconToBoard()

    --在棋盘上显示该随机棋子
    local blinkSprite = createBlinkIconSprite()
    local blinkStartPoint = getCellCenterPoint({x = 6, y = 10})
    blinkSprite:setPosition(blinkStartPoint.x, blinkStartPoint.y)
    scene:addChild(blinkSprite)

    --随机落到棋盘某个点并改变该点数据
    math.randomseed(math.random(os.time()))
    local x = math.random(GBoardSizeX)
    local y = math.random(GBoardSizeY)

    --提前修改棋盘数据防止过程中交换
    GameBoard[x][y] = GBlinkIconIndex
    blinkCell = {x = x, y = y}
    CCLuaLog(blinkSprite:getTexture():getName())

    local fallEndPoint = getCellCenterPoint({x = x, y = y})


    local function cfblinkFallEnd()
        local tag = 10 * blinkCell.x + blinkCell.y
        local node = scene:getChildByTag(NODE_TAG_START + tag)
        node:removeFromParentAndCleanup(true)
        blinkSprite:setTag(NODE_TAG_START + tag)
        local node = scene:getChildByTag(NODE_TAG_START+tag)
    end

    local arrayOfActions = CCArray:create()

    local move = CCMoveTo:create(0.2, CCPoint(fallEndPoint.x , fallEndPoint.y))
    local blinkFallEnd = CCCallFunc:create(cfblinkFallEnd)

    arrayOfActions:addObject(move)
    arrayOfActions:addObject(blinkFallEnd)

    local sequence = CCSequence:create(arrayOfActions)

    blinkSprite:runAction(sequence)
end

--检测落下的棋子是否命中
function cfCheckFallCell()
    CCLuaLog("cfCheckFallCell...")
    local boardMovable , succList= checkBoardMovable()
    if #succList <= 3 then
        addBlinkIconToBoard()
    end
    --[[
    if boardMovable then
        CCLuaLog("checkBoardMovable true")
        CCLuaLog("succList size : "..#succList)
    else
        CCLuaLog("checkBoardMovable false ")
        addBlinkIconToBoard()
    end
    ]]

    --复制为局部变量
    local checkSet = {}
    for i = 1, #fallCellSet do
        checkSet[#checkSet + 1] = fallCellSet[i]
    end

    --重置全局table
    switchCellSet = {}

    --匹配成功的格子点
    succCellSet = {}
    for i = 1, #checkSet do
        local canRemove,result = checkCell2(checkSet[i])
        if canRemove then
            succCellSet[#succCellSet + 1] = {cell=checkSet[i],result=result}
        end
    end

    if #succCellSet ~= 0 then
        onCheckSuccess(succCellSet)
    end
end

--检测互相交换的两个格子是否命中
function cfCheckSwitchCell()
    --CCLuaLog("cfCheckSwitchCell...")

    --复制为局部变量
    local checkSet = {}
    for i = 1, #switchCellSet do
        checkSet[#checkSet + 1] = switchCellSet[i]
    end

    --重置全局table
    switchCellSet = {}

    if #checkSet < 2 then
        return
    end

    --匹配成功的格子点
    succCellSet = {}
    for i = 1, #checkSet do
        local canRemove,result = checkCell2(checkSet[i])
        if canRemove then
            succCellSet[#succCellSet + 1] = {cell=checkSet[i],result=result}
        end
    end

    if #succCellSet == 0 then
        --匹配失败
        CCLuaLog("switch failed...")

        --还原移动并清空交换区
        switchCell(switchCellPair[1], switchCellPair[2], nil)
        switchCellPair = {}

        AudioEngine.playEffect("effect/A_falsemove.wav")
    else
        onCheckSuccess(succCellSet)
    end
end

--背景层
local function createBackLayer()
    local backLayer = CCLayer:create()

    local backSprite = CCSprite:create("game_bg.png")
    backSprite:setPosition(backSprite:getContentSize().width / 2, backSprite:getContentSize().height / 2)

    backLayer:addChild(backSprite)


    return backLayer
end

--触摸层
local function createTouchLayer()

    local touchColor = Color4B:new(255, 255, 255 ,0)
    local touchLayer = CCLayerColor:create(touchColor)

    touchLayer:changeWidthAndHeight(visibleSize.width, visibleSize.height)

    local function onTouchBegan(x, y)
        --CCLuaLog("touchLayerBegan: %.2f, %.2f", x, y)
        isTouching = true
        touchStartPoint = {x = x, y = y}
        touchStartCell = touchPointToCell(x, y)
        if curSelectTag ~= nil then
            local curSelectCell = {x = math.modf(curSelectTag / 10), y = curSelectTag % 10}
            if isTwoCellNearby(curSelectCell, touchStartCell) then
                switchCellSet = {}
                switchCellSet[#switchCellSet + 1] = curSelectCell
                switchCellSet[#switchCellSet + 1] = touchStartCell

                switchCellPair[1] = curSelectCell
                switchCellPair[2] = touchStartCell
                switchCell(curSelectCell, touchStartCell, cfCheckSwitchCell)

                return true
            end
        end
        -- 清除blink相同的
        if GameBoard[touchStartCell.x][touchStartCell.y] == GBlinkIconIndex then
            onClickBlinkCell(touchStartCell)
        else
            onClickGameIcon(touchStartCell)
        end

        return true
    end

    local function onTouchMoved(x, y)
        --CCLuaLog("touchLayerMoved: %.2f, %.2f", x, y)
        local touchCurCell = touchPointToCell(x, y)
        if  isTouching then
            if isTwoCellNearby(touchCurCell, touchStartCell) then
                switchCellSet = {}
                switchCellSet[#switchCellSet + 1] = touchCurCell
                switchCellSet[#switchCellSet + 1] = touchStartCell

                switchCellPair[1] = touchCurCell
                switchCellPair[2] = touchStartCell
                switchCell(touchCurCell, touchStartCell, cfCheckSwitchCell)
            end
        end
    end

    local function onTouchEnded(x, y)
        --CCLuaLog("touchLayerEnded: %.2f, %.2f", x, y)
        touchEndPoint = {x = x, y = y}
        touchEndCell = touchPointToCell(x, y)
        isTouching = false
    end


    local function onTouch(eventType, x, y)
        if eventType == "began" then
            return onTouchBegan(x, y)
        elseif eventType == "moved" then
            return onTouchMoved(x, y)
        elseif eventType == "ended" then
            return onTouchEnded(x, y)
        end
    end

    touchLayer:registerScriptTouchHandler(onTouch)
    touchLayer:setTouchEnabled(true)

    return touchLayer
end


-- create game scene
function CreateGameScene()

    scene = CCScene:create()
    scene:addChild(createBackLayer())

    AudioEngine.stopMusic(true)

    local bgMusicPath = CCFileUtils:getInstance():fullPathForFilename("music/bgm_game.wav")
    AudioEngine.playMusic(bgMusicPath, true)

    loadGameIcon()

    initGameBoard()
    initGameBoardIcon()

    scene:addChild(createTouchLayer(), 1000)

    --创建用于延迟执行刷新棋盘函数的节点
    RefreshBoardNode = CCNode:create()
    scene:addChild(RefreshBoardNode)

    FallEndCheckNode = CCNode:create()
    scene:addChild(FallEndCheckNode)

    -- 分数显示
    ScoreLabel = CCLabelTTF:create("Score : 0", "Marker Felt", 50)
    scene:addChild(ScoreLabel)
    ScoreLabel:setPosition(visibleSize.width/2,visibleSize.height*0.9)

    TotalScore = 0

    return scene
end
