local videoConfigs = {
    {
        step = 616,
        tag = "video1",
        name = "yararara/2",        
        x = -300,          -- 此值在底部居中逻辑下不再用于定位，但仍保留
        y = -200,
        scaleX = 0.7,
        scaleY = 0.7,
        cam = "hud",
        sound = false,
        loop = false,
        volume = 0
    },
        {
        step = 1152,
        tag = "video1",
        name = "yararara/3",        
        x = -300,          -- 此值在底部居中逻辑下不再用于定位，但仍保留
        y = -200,
        scaleX = 0.7,
        scaleY = 0.7,
        cam = "hud",
        sound = false,
        loop = false,
        volume = 0
    },
}
local activeVideos = {}

function onStepHit()
    for _, config in ipairs(videoConfigs) do
        if curStep == config.step then
            createVideoSprite(config)
            break
        end
    end
end

function createVideoSprite(config)
    local tag = config.tag or ('video' .. tostring(math.random(1000, 9999)))
    local cameraName = 'camGame'
    if config.cam == 'hud' then
        cameraName = 'camHUD'
    elseif config.cam == 'other' then
        cameraName = 'camOther'
    end
    runHaxeCode([[
        try {
            import hxvlc.flixel.FlxVideoSprite;
            import flixel.util.FlxTimer;
            import flixel.tweens.FlxTween;
            import flixel.FlxG;
            
            var ]] .. tag .. [[:FlxVideoSprite = new FlxVideoSprite(]] .. (config.x or 0) .. [[, ]] .. (config.y or 0) .. [[);
            
            ]] .. tag .. [[.visible = false;
            ]] .. tag .. [[.alpha = 0;
            
            var videoPath:String = Paths.video("]] .. config.name .. [[");
            trace('Loading video from: ' + videoPath);
            
            if (videoPath == null || videoPath.length == 0) {
                trace('ERROR: Video file not found: ]] .. config.name .. [[');
                return;
            }
            
            var loaded:Bool = ]] .. tag .. [[.load(videoPath, ]] .. tostring(config.loop == true) .. [[, false);
            
            if (!loaded) {
                trace('ERROR: Failed to load video: ' + videoPath);
                return;
            }
            
            trace('Video loaded successfully: ' + videoPath);
            
            // 先设置初始缩放（将在 onFormatSetup 中被覆盖，但保留以防万一）
            ]] .. tag .. [[.scale.x = ]] .. (config.scaleX or 1) .. [[;
            ]] .. tag .. [[.scale.y = ]] .. (config.scaleY or 1) .. [[;
            
            // ★★★ 修改：将视频插入到状态的最底层（索引 0），确保位于所有已存在 HUD 元素的下方 ★★★
            // 这样箭头等元素会绘制在视频之上，实现“视频在箭头下方”的层级效果
            FlxG.state.insert(0, ]] .. tag .. [[);
            
            // 设置相机
            var camObj = null;
            if ("]] .. cameraName .. [[" == "camHUD") camObj = camHUD;
            else if ("]] .. cameraName .. [[" == "camGame") camObj = camGame;
            else if ("]] .. cameraName .. [[" == "camOther") camObj = camOther;
            
            if (camObj != null) {
                ]] .. tag .. [[.camera = camObj;
                trace('Camera set to: ' + camObj);
            }
            
            setVar("]] .. tag .. [[", ]] .. tag .. [[);
            
            if (]] .. tag .. [[.bitmap != null) {
                ]] .. tag .. [[.bitmap.onFormatSetup.add(function():Void {
                    trace('Video format setup complete for: ]] .. tag .. [[');
                    
                    // ★ 修改：使用配置中的缩放值，而不是硬编码 0.7 ★
                    ]] .. tag .. [[.scale.set(]] .. (config.scaleX or 1) .. [[, ]] .. (config.scaleY or 1) .. [[);
                    ]] .. tag .. [[.updateHitbox();
                    
                    var screenWidth = FlxG.width;
                    var screenHeight = FlxG.height;
                    
                    var videoWidth = ]] .. tag .. [[.width;
                    var videoHeight = ]] .. tag .. [[.height;
                    
                    // ★ 修改：水平居中，垂直底部（距底部 50 像素，可调整） ★
                    ]] .. tag .. [[.x = (screenWidth - videoWidth) / 2;
                    ]] .. tag .. [[.y = screenHeight - videoHeight + 30;  
                    
                    trace('Video positioned at: (' + ]] .. tag .. [[.x + ', ' + ]] .. tag .. [[.y + ')');
                });
                
                if (!]] .. tostring(config.loop == true) .. [[) {
                    ]] .. tag .. [[.bitmap.onEndReached.add(function():Void {
                        trace('Video ended: ]] .. tag .. [[');
                        callOnLuas("onVideoFinished", ["]] .. tag .. [["]);
                    });
                }
            }
            
            new FlxTimer().start(0.05, function(_):Void {
                ]] .. tag .. [[.visible = true;
                FlxTween.tween(]] .. tag .. [[, {alpha: 1}, 0.2);
                ]] .. tag .. [[.play();
                if (]] .. tag .. [[.bitmap != null) {
                    ]] .. tag .. [[.bitmap.volume = ]] .. (config.sound and (config.volume or 1) or 0) .. [[;
                }
                trace('Video playback started: ]] .. tag .. [[');
            });
            
        } catch(e:Dynamic) {
            trace('ERROR creating video sprite: ' + e);
        }
    ]])
    
    activeVideos[tag] = {
        config = config,
        createdAt = getSongPosition()
    }
    
    return tag
end

function onVideoFinished(tag)
    local data = activeVideos[tag]
    if data and data.config.loop then
        runHaxeCode([[
            try {
                var vid = getVar("]] .. tag .. [[");
                if (vid != null) {
                    vid.play();
                }
            } catch(e:Dynamic) {}
        ]])
    else
        runHaxeCode([[
            try {
                var vid = getVar("]] .. tag .. [[");
                if (vid != null) {
                    vid.pause();
                    FlxTween.tween(vid, {alpha: 0}, 0.5, {
                        onComplete: function(_):Void {
                            callOnLuas("removeVideoSprite", ["]] .. tag .. [["]);
                        }
                    });
                }
            } catch(e:Dynamic) {}
        ]])
    end
end

function onPause()
    for tag, _ in pairs(activeVideos) do
        runHaxeCode([[
            try {
                var vid = getVar("]] .. tag .. [[");
                if (vid != null && vid.bitmap != null) {
                    vid.pause();
                    trace('Video paused: ]] .. tag .. [[');
                }
            } catch(e:Dynamic) {}
        ]])
    end
end

function onResume()
    for tag, _ in pairs(activeVideos) do
        runHaxeCode([[
            try {
                var vid = getVar("]] .. tag .. [[");
                if (vid != null && vid.bitmap != null) {
                    vid.resume();
                    trace('Video resumed: ]] .. tag .. [[');
                }
            } catch(e:Dynamic) {}
        ]])
    end
end

function onUpdate(elapsed)
end

function onDestroy()
    for tag, _ in pairs(activeVideos) do
        removeVideoSprite(tag)
    end
end

function removeVideoSprite(tag)
    if not activeVideos[tag] then return end
    
    runHaxeCode([[
        try {
            var vid = getVar("]] .. tag .. [[");
            if (vid != null) {
                if (vid.bitmap != null) {
                    vid.bitmap.stop();
                }
                vid.destroy();
                setVar("]] .. tag .. [[", null);
                trace('Video removed: ]] .. tag .. [[');
            }
        } catch(e:Dynamic) {
            trace('Error removing video: ' + e);
        }
    ]])
    
    activeVideos[tag] = nil
end

function pauseVideo(tag)
    if not activeVideos[tag] then return end
    runHaxeCode([[
        try {
            var vid = getVar("]] .. tag .. [[");
            if (vid != null) vid.pause();
        } catch(e:Dynamic) {}
    ]])
end

function resumeVideo(tag)
    if not activeVideos[tag] then return end
    runHaxeCode([[
        try {
            var vid = getVar("]] .. tag .. [[");
            if (vid != null) vid.resume();
        } catch(e:Dynamic) {}
    ]])
end

function stopVideo(tag)
    if not activeVideos[tag] then return end
    runHaxeCode([[
        try {
            var vid = getVar("]] .. tag .. [[");
            if (vid != null) vid.pause();
        } catch(e:Dynamic) {}
    ]])
end

function setVideoAlpha(tag, alpha)
    if not activeVideos[tag] then return end
    runHaxeCode([[
        try {
            var vid = getVar("]] .. tag .. [[");
            if (vid != null) vid.alpha = ]] .. math.max(0, math.min(1, alpha)) .. [[;
        } catch(e:Dynamic) {}
    ]])
end

function setVideoVolume(tag, volume)
    if not activeVideos[tag] then return end
    volume = math.max(0, math.min(1, volume))
    runHaxeCode([[
        try {
            var vid = getVar("]] .. tag .. [[");
            if (vid != null && vid.bitmap != null) {
                vid.bitmap.volume = ]] .. volume .. [[;
            }
        } catch(e:Dynamic) {}
    ]])
end

function setVideoPosition(tag, x, y)
    if not activeVideos[tag] then return end
    runHaxeCode([[
        try {
            var vid = getVar("]] .. tag .. [[");
            if (vid != null) {
                vid.x = ]] .. (x or 0) .. [[;
                vid.y = ]] .. (y or 0) .. [[;
            }
        } catch(e:Dynamic) {}
    ]])
end

function setVideoScale(tag, scaleX, scaleY)
    if not activeVideos[tag] then return end
    runHaxeCode([[
        try {
            var vid = getVar("]] .. tag .. [[");
            if (vid != null) {
                vid.scale.x = ]] .. (scaleX or 1) .. [[;
                vid.scale.y = ]] .. (scaleY or scaleX or 1) .. [[;
            }
        } catch(e:Dynamic) {}
    ]])
end

function makeVideoSprite(tag, videoPath, x, y, camera, hasVolume)
    return createVideoSprite({
        tag = tag,
        name = videoPath,
        x = x or 0,
        y = y or 0,
        scaleX = 1,
        scaleY = 1,
        cam = camera or 'hud',
        sound = hasVolume or false,
        volume = 1,
        loop = false
    })
end

function createMultipleVideos(videoConfigs)
    for _, config in ipairs(videoConfigs) do
        createVideoSprite(config)
    end
end

function checkVideoStatus(tag)
    runHaxeCode([[
        try {
            var vid = getVar("]] .. (tag or 'video') .. [[");
            if (vid != null) {
                trace('=== Video Status: ]] .. (tag or 'video') .. [[ ===');
                trace('  Type: ' + Type.getClassName(Type.getClass(vid)));
                trace('  visible: ' + vid.visible);
                trace('  alpha: ' + vid.alpha);
                trace('  x: ' + vid.x + ', y: ' + vid.y);
                trace('  scale: ' + vid.scale.x + 'x' + vid.scale.y);
                trace('  camera: ' + (vid.camera != null ? Std.string(vid.camera) : 'null'));
                if (vid.bitmap != null) {
                    trace('  bitmap exists: true');
                    trace('  isPlaying: ' + vid.bitmap.isPlaying);
                    trace('  volume: ' + vid.bitmap.volume);
                    if (vid.bitmap.bitmapData != null) {
                        trace('  bitmapData size: ' + vid.bitmap.bitmapData.width + 'x' + vid.bitmap.bitmapData.height);
                    }
                } else {
                    trace('  bitmap: null');
                }
            } else {
                trace('ERROR: Video not found: ]] .. (tag or 'video') .. [[');
            }
        } catch(e:Dynamic) {
            trace('Error checking video: ' + e);
        }
    ]])
end