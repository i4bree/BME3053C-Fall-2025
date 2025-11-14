-- Pong implemented with LÖVE 11.x

local windowW, windowH = 800, 600
local paddleW, paddleH = 12, 90
local ballSize = 12

local leftPaddle = { x = 30, y = 0, w = paddleW, h = paddleH, speed = 360 }
local rightPaddle = { x = 0, y = 0, w = paddleW, h = paddleH, speed = 360 }

local ball = { x = 0, y = 0, w = ballSize, h = ballSize, vx = 0, vy = 0, baseSpeed = 260, speed = 260 }

local scoreLeft, scoreRight = 0, 0
local winScore = 10
local gameState = "start" -- start | serve | play | done
local servingPlayer = 1
local winner = nil
local aiRight = true
local aiMaxSpeed = 340

local smallFont, scoreFont, infoFont

-- Ball color (RGB 0..1)
local ballColor = {1, 1, 1}

local function randomBallColor()
  -- Generate a bright random color; ensure at least one channel is strong
  local r, g, b = math.random(), math.random(), math.random()
  local m = math.max(r, g, b)
  if m < 0.6 then
    local s = 0.6 / math.max(m, 0.01)
    r, g, b = math.min(r * s, 1), math.min(g * s, 1), math.min(b * s, 1)
  end
  ballColor[1], ballColor[2], ballColor[3] = r, g, b
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function aabb(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function centerPaddles()
  leftPaddle.y = (windowH - leftPaddle.h) / 2
  rightPaddle.x = windowW - 30 - rightPaddle.w
  rightPaddle.y = (windowH - rightPaddle.h) / 2
end

local function resetBall(toPlayer)
  ball.x = (windowW - ball.w) / 2
  ball.y = (windowH - ball.h) / 2
  ball.speed = ball.baseSpeed
  local dir = toPlayer == 1 and -1 or 1
  ball.vx = dir * ball.speed
  ball.vy = (math.random() * 2 - 1) * ball.speed * 0.6
end

local function startServe()
  gameState = "serve"
  resetBall(servingPlayer)
end

function love.load()
  love.window.setTitle("Pong - LÖVE")
  love.window.setMode(windowW, windowH, { resizable = false, vsync = 1 })
  math.randomseed(love.timer.getTime())

  smallFont = love.graphics.newFont(14)
  scoreFont = love.graphics.newFont(48)
  infoFont = love.graphics.newFont(18)

  centerPaddles()
  randomBallColor()
  startServe()
end

local function updateAI(dt)
  local targetY = ball.y + ball.h / 2 - rightPaddle.h / 2
  local dy = targetY - rightPaddle.y
  local step = clamp(dy, -aiMaxSpeed * dt, aiMaxSpeed * dt)
  rightPaddle.y = rightPaddle.y + step
end

local function paddleInput(dt)
  -- Left paddle: W/S
  if love.keyboard.isDown("w") then
    leftPaddle.y = leftPaddle.y - leftPaddle.speed * dt
  elseif love.keyboard.isDown("s") then
    leftPaddle.y = leftPaddle.y + leftPaddle.speed * dt
  end

  -- Right paddle: Up/Down when not AI
  if not aiRight then
    if love.keyboard.isDown("up") then
      rightPaddle.y = rightPaddle.y - rightPaddle.speed * dt
    elseif love.keyboard.isDown("down") then
      rightPaddle.y = rightPaddle.y + rightPaddle.speed * dt
    end
  end

  leftPaddle.y = clamp(leftPaddle.y, 0, windowH - leftPaddle.h)
  rightPaddle.y = clamp(rightPaddle.y, 0, windowH - rightPaddle.h)
end

local function ballBounceWalls()
  if ball.y <= 0 then
    ball.y = 0
    ball.vy = -ball.vy
    randomBallColor()
  elseif ball.y + ball.h >= windowH then
    ball.y = windowH - ball.h
    ball.vy = -ball.vy
    randomBallColor()
  end
end

local function addSpin(paddle)
  local paddleCenter = paddle.y + paddle.h / 2
  local ballCenter = ball.y + ball.h / 2
  local offset = (ballCenter - paddleCenter) / (paddle.h / 2)
  ball.vy = ball.vy + offset * 80
end

local function ballBouncePaddles()
  if aabb(ball, leftPaddle) and ball.vx < 0 then
    ball.x = leftPaddle.x + leftPaddle.w
    ball.vx = -ball.vx
    ball.speed = ball.speed * 1.05
    local signX = ball.vx < 0 and -1 or 1
    ball.vx = signX * ball.speed
    addSpin(leftPaddle)
    randomBallColor()
  elseif aabb(ball, rightPaddle) and ball.vx > 0 then
    ball.x = rightPaddle.x - ball.w
    ball.vx = -ball.vx
    ball.speed = ball.speed * 1.05
    local signX = ball.vx < 0 and -1 or 1
    ball.vx = signX * ball.speed
    addSpin(rightPaddle)
    randomBallColor()
  end
end

local function checkScore()
  if ball.x + ball.w < 0 then
    scoreRight = scoreRight + 1
    servingPlayer = 1
    if scoreRight >= winScore then
      winner = "Right"
      gameState = "done"
    else
      startServe()
    end
  elseif ball.x > windowW then
    scoreLeft = scoreLeft + 1
    servingPlayer = 2
    if scoreLeft >= winScore then
      winner = "Left"
      gameState = "done"
    else
      startServe()
    end
  end
end

function love.update(dt)
  if gameState == "play" then
    paddleInput(dt)
    if aiRight then updateAI(dt) end

    ball.x = ball.x + ball.vx * dt
    ball.y = ball.y + ball.vy * dt

    ballBounceWalls()
    ballBouncePaddles()
    checkScore()
  elseif gameState == "serve" then
    paddleInput(dt)
    if aiRight then updateAI(dt) end
    -- Ball stays centered with initial velocity ready until serve
  elseif gameState == "start" or gameState == "done" then
    -- Idle until keypress
  end
end

function love.keypressed(key)
  if key == "escape" then love.event.quit() end

  if key == "return" or key == "enter" or key == "space" then
    if gameState == "start" then
      gameState = "serve"
    elseif gameState == "serve" then
      gameState = "play"
    elseif gameState == "done" then
      scoreLeft, scoreRight = 0, 0
      winner = nil
      gameState = "serve"
      resetBall(servingPlayer)
      centerPaddles()
    end
  end

  if key == "tab" then
    aiRight = not aiRight
  end

  if key == "r" then
    scoreLeft, scoreRight = 0, 0
    servingPlayer = math.random(2)
    winner = nil
    centerPaddles()
    startServe()
  end
end

local function drawCenterLine()
  love.graphics.setColor(1, 1, 1, 0.3)
  for y = 0, windowH, 24 do
    love.graphics.rectangle("fill", windowW / 2 - 2, y, 4, 12)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function love.draw()
  love.graphics.clear(0.05, 0.05, 0.08, 1)

  drawCenterLine()

  -- Scores
  love.graphics.setFont(scoreFont)
  love.graphics.print(tostring(scoreLeft), windowW / 2 - 80, 40)
  love.graphics.print(tostring(scoreRight), windowW / 2 + 40, 40)

  -- Paddles and ball
  love.graphics.rectangle("fill", leftPaddle.x, leftPaddle.y, leftPaddle.w, leftPaddle.h)
  love.graphics.rectangle("fill", rightPaddle.x, rightPaddle.y, rightPaddle.w, rightPaddle.h)
  love.graphics.setColor(ballColor)
  love.graphics.rectangle("fill", ball.x, ball.y, ball.w, ball.h)
  love.graphics.setColor(1, 1, 1, 1)

  -- Messages
  love.graphics.setFont(infoFont)
  local info = "W/S: Left  |  Up/Down: Right  |  TAB: Toggle AI  |  Enter/Space: Serve  |  R: Reset"
  love.graphics.printf(info, 0, windowH - 30, windowW, "center")

  love.graphics.setFont(smallFont)
  if gameState == "start" then
    love.graphics.printf("Pong! Press Enter/Space to begin.", 0, windowH * 0.25, windowW, "center")
  elseif gameState == "serve" then
    local who = servingPlayer == 1 and "Left" or "Right"
    love.graphics.printf("" .. who .. " to serve. Press Enter/Space!", 0, windowH * 0.25, windowW, "center")
  elseif gameState == "done" and winner then
    love.graphics.printf("" .. winner .. " wins! Press Enter/Space to restart.", 0, windowH * 0.25, windowW, "center")
  end
end