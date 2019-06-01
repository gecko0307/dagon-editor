/*
Copyright (c) 2019 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module editor;

import std.stdio;
import dagon;

class Editor: Scene
{
    Game game;
    
    LoadingScreen loadingScreen;
    
    FontAsset aFont;
    
    OBJAsset aCerberus;
    TextureAsset aTexCerberusAlbedo;
    TextureAsset aTexCerberusNormal;
    TextureAsset aTexCerberusRoughness;
    TextureAsset aTexCerberusMetallic;
    
    ImageAsset aHeightmap;
    TextureAsset aTexDesertAlbedo;
    TextureAsset aTexDesertNormal;
    TextureAsset aTexDesertRoughness;
    TextureAsset aEnvmap;
    
    Camera camera;
    FreeviewComponent freeview;
    
    Light sun;
    
    Entity eTerrain;
    Entity eModel;
    
    FreeTypeFont font;
    Entity text;
    TextLine infoText;
    
    NuklearGUI gui;
    bool envColorPicker = false;
    Color4f envColor = Color4f(0.8f, 0.8f, 1.0f, 1.0f);
    
    float sunPitch = -45.0f;
    float sunTurn = 0.0f;
    
    int useTextures = 1;
    
    Color4f diffuseColor;
    bool diffuseColorPicker = false;
    
    float roughness = 0.5f;
    float metallic = 0.0f;
    
    this(Game game)
    {
        super(game);
        this.game = game;
        loadingScreen = New!LoadingScreen(game, this);
    }
    
    override void beforeLoad()
    {
        aFont = addFontAsset("data/font/DroidSans.ttf", 14);
        
        aCerberus = addOBJAsset("data/cerberus/cerberus.obj");
        aTexCerberusAlbedo = addTextureAsset("data/cerberus/cerberus-albedo.png");
        aTexCerberusNormal = addTextureAsset("data/cerberus/cerberus-normal.png");
        aTexCerberusRoughness = addTextureAsset("data/cerberus/cerberus-roughness.png");
        aTexCerberusMetallic = addTextureAsset("data/cerberus/cerberus-metallic.png");
        
        aHeightmap = addImageAsset("data/terrain/heightmap.png");
        aTexDesertAlbedo = addTextureAsset("data/terrain/desert-albedo.png");
        aTexDesertNormal = addTextureAsset("data/terrain/desert-normal.png");
        aTexDesertRoughness = addTextureAsset("data/terrain/desert-roughness.png");
        
        aEnvmap = addTextureAsset("data/TropicalRuins_Env.hdr");
    }

    override void onLoad(Time t, float progress)
    {
        loadingScreen.update(t, progress);
        loadingScreen.render();
    }
    
    override void afterLoad()
    {
        auto envCubemap = New!Cubemap(1024, assetManager);
        envCubemap.fromEquirectangularMap(aEnvmap.texture);
        environment.ambientMap = envCubemap;
    
        camera = addCamera();
        freeview = New!FreeviewComponent(eventManager, camera);
        freeview.zoom(-100);
        game.renderer.activeCamera = camera;
        
        game.deferredRenderer.ssaoPower = 6.0;
        
        sun = addLight(LightType.Sun);
        sun.position.y = 50.0f;
        sun.shadowEnabled = true;
        sun.energy = 10.0f;
        
        eTerrain = addEntity();
        eTerrain.position = Vector3f(-64, 0, -64);
        eTerrain.material = New!Material(null, assetManager);
        eTerrain.material.textureScale = Vector2f(10.0f, 10.0f);
        eTerrain.material.diffuse = aTexDesertAlbedo.texture;
        eTerrain.material.normal = aTexDesertNormal.texture;
        eTerrain.material.roughness = aTexDesertRoughness.texture;
        
        auto heightmap = New!ImageHeightmap(aHeightmap.image, 30.0f, assetManager);
        auto terrain = New!Terrain(512, 64, heightmap, assetManager);
        eTerrain.drawable = terrain;
        eTerrain.scaling = Vector3f(0.25f, 0.25f, 0.25f);
        
        eModel = addEntity();
        eModel.position.y = 7.0f;
        eModel.scaling = Vector3f(1.0f, 1.0f, 1.0f);
        eModel.drawable = aCerberus.mesh;
        eModel.material = New!Material(null, assetManager);
        eModel.material.diffuse = aTexCerberusAlbedo.texture;
        eModel.material.normal = aTexCerberusNormal.texture;
        eModel.material.roughness = aTexCerberusRoughness.texture;
        eModel.material.metallic = aTexCerberusMetallic.texture;
        diffuseColor = Color4f(0.5f, 0.5f, 0.5f, 1.0f);
        
        gui = New!NuklearGUI(eventManager, assetManager);
        gui.addFont(aFont, 18, gui.localeGlyphRanges);
        auto eNuklear = addEntityHUD();
        eNuklear.drawable = gui;
        
        text = addEntityHUD();
        infoText = New!TextLine(aFont.font, "Hello, World!", assetManager);
        infoText.color = Color4f(0.6f, 0.6f, 0.6f, 1.0f);
        text.drawable = infoText;
        text.position.x = 10;
        text.position.y = eventManager.windowHeight - 10;
    }
    
    char[100] textBuffer;
    
    override void onUpdate(Time t)
    {
        text.position.y = eventManager.windowHeight - 10;
        
        uint n = sprintf(textBuffer.ptr, "FPS: %u", eventManager.fps);
        string s = cast(string)textBuffer[0..n];
        infoText.setText(s);
        
        updateUserInterface(t);
        
        environment.backgroundColor = envColor;
        environment.ambientColor = envColor * 0.25f;
        environment.fogColor = envColor;
        
        sun.rotation = 
            rotationQuaternion!float(Axis.y, degtorad(sunTurn)) *
            rotationQuaternion!float(Axis.x, degtorad(sunPitch));
        
        if (!useTextures)
        {
            eModel.material.diffuse = diffuseColor;
            eModel.material.roughness = roughness;
            eModel.material.metallic = metallic;
        }
        else
        {
            eModel.material.diffuse = aTexCerberusAlbedo.texture;
            eModel.material.roughness = aTexCerberusRoughness.texture;
            eModel.material.metallic = aTexCerberusMetallic.texture;
        }
    }

    override void onKeyDown(int key)
    {
        if (key == KEY_ESCAPE)
            application.exit();
        else if (key == KEY_BACKSPACE)
            gui.inputKeyDown(NK_KEY_BACKSPACE);
        else if (key == KEY_C && eventManager.keyPressed[KEY_LCTRL])
            gui.inputKeyDown(NK_KEY_COPY);
        else if (key == KEY_V && eventManager.keyPressed[KEY_LCTRL])
            gui.inputKeyDown(NK_KEY_PASTE);
        else if (key == KEY_A && eventManager.keyPressed[KEY_LCTRL])
            gui.inputKeyDown(NK_KEY_TEXT_SELECT_ALL);
    }
    
    override void onKeyUp(int key)
    {
        if (key == KEY_BACKSPACE)
            gui.inputKeyUp(NK_KEY_BACKSPACE);
    }
    
    override void onMouseButtonDown(int button)
    {
        gui.inputButtonDown(button);
        freeview.active = !gui.itemIsAnyActive();
        freeview.prevMouseX = eventManager.mouseX;
        freeview.prevMouseY = eventManager.mouseY;
    }
    
    override void onMouseButtonUp(int button)
    {
        gui.inputButtonUp(button);
    }

    override void onTextInput(dchar unicode)
    {
        gui.inputUnicode(unicode);
    }

    override void onMouseWheel(int x, int y)
    {
        freeview.active = !gui.itemIsAnyActive();
        if (!freeview.active)
            gui.inputScroll(x, y);
    }

    void updateUserInterface(Time t)
    {
        gui.update(t);
        
        if (gui.begin("Menu", NKRect(0, 0, eventManager.windowWidth, 40), 0))
        {
            gui.menubarBegin();
            {
                gui.layoutRowStatic(30, 40, 5);

                if (gui.menuBeginLabel("File", NK_TEXT_LEFT, NKVec2(200, 200)))
                {
                    gui.layoutRowDynamic(25, 1);
                    if (gui.menuItemLabel("New", NK_TEXT_LEFT)) { }
                    if (gui.menuItemLabel("Open", NK_TEXT_LEFT)) { }
                    if (gui.menuItemLabel("Save", NK_TEXT_LEFT)) { }
                    if (gui.menuItemLabel("Exit", NK_TEXT_LEFT)) { application.exit(); }
                    gui.menuEnd();
                }
                
                if (gui.menuBeginLabel("Edit", NK_TEXT_LEFT, NKVec2(200, 200)))
                {
                    gui.layoutRowDynamic(25, 1);
                    if (gui.menuItemLabel("Copy", NK_TEXT_LEFT)) { }
                    if (gui.menuItemLabel("Paste", NK_TEXT_LEFT)) { }
                    gui.menuEnd();
                }
                
                if (gui.menuBeginLabel("Help", NK_TEXT_LEFT, NKVec2(200, 200)))
                {
                    gui.layoutRowDynamic(25, 1);
                    if (gui.menuItemLabel("About...", NK_TEXT_LEFT)) { }
                    gui.menuEnd();
                }
            }
            gui.menubarEnd();
        }
        gui.end();
        
        if (gui.begin("Properties", NKRect(0, 40, 300, eventManager.windowHeight - 40), NK_WINDOW_TITLE))
        {
            if (gui.treePush(NK_TREE_NODE, "Render", NK_MAXIMIZED))
            {
                gui.layoutRowDynamic(30, 2);
                gui.label("Output:", NK_TEXT_LEFT);
                game.deferredRenderer.outputMode = 
                    cast(DebugOutputMode)gui.comboString(
                        "Radiance\0Albedo\0Normal\0Position\0Roughness\0Metallic\0Occlusion", 
                        game.deferredRenderer.outputMode, 7, 25, NKVec2(120, 250));
                
				gui.layoutRowDynamic(25, 1);
				game.deferredRenderer.ssaoSamples = gui.property("AO samples:", 1, game.deferredRenderer.ssaoSamples, 25, 1, 1);
				game.deferredRenderer.ssaoRadius = gui.property("AO radius:", 0.05f, game.deferredRenderer.ssaoRadius, 1.0f, 0.01f, 0.005f);
                game.deferredRenderer.ssaoPower = gui.property("AO power:", 0.0f, game.deferredRenderer.ssaoPower, 10.0f, 0.01f, 0.01f);
                game.deferredRenderer.ssaoDenoise = gui.property("AO denoise:", 0.0f, game.deferredRenderer.ssaoDenoise, 1.0f, 0.01f, 0.01f);
				
                gui.layoutRowDynamic(25, 1);
                game.postProcRenderer.glowThreshold = gui.property("Glow threshold:", 0.0f, game.postProcRenderer.glowThreshold, 1.0f, 0.01f, 0.005f);
                game.postProcRenderer.glowIntensity = gui.property("Glow intensity:", 0.0f, game.postProcRenderer.glowIntensity, 1.0f, 0.01f, 0.005f);
                
                gui.layoutRowDynamic(25, 1);
                game.postProcRenderer.glowRadius = gui.property("Glow radius:", 1, game.postProcRenderer.glowRadius, 10, 1, 1);
                
                gui.layoutRowDynamic(30, 2);
                gui.label("Tonemapper:", NK_TEXT_LEFT);
                game.postProcRenderer.tonemapper = 
                    cast(Tonemapper)gui.comboString(
                        "None\0Reinhard\0Hable\0ACES", 
                        game.postProcRenderer.tonemapper, 4, 25, NKVec2(120, 200));
                
                gui.layoutRowDynamic(25, 1);
                game.postProcRenderer.exposure = gui.property("Exposure:", 0.0f, game.postProcRenderer.exposure, 2.0f, 0.01f, 0.005f);
                
                gui.treePop();
            }
            
            if (gui.treePush(NK_TREE_NODE, "Environment", NK_MINIMIZED))
            {
                gui.layoutRowDynamic(25, 2);
                gui.label("Background color:", NK_TEXT_LEFT);
                if (gui.buttonColor(envColor)) 
                    envColorPicker = !envColorPicker;
                
                if (envColorPicker)
                {
                    NKRect s = NKRect(300, 100, 300, 350);
                    if (gui.popupBegin(NK_POPUP_STATIC, "Color", NK_WINDOW_CLOSABLE, s))
                    {
                        gui.layoutRowDynamic(180, 1);
                        envColor = gui.colorPicker(envColor, NK_RGB);
                        gui.layoutRowDynamic(25, 1);
                        envColor.r = gui.property("#R:", 0.0f, envColor.r, 1.0f, 0.01f, 0.005f);
                        envColor.g = gui.property("#G:", 0.0f, envColor.g, 1.0f, 0.01f, 0.005f);
                        envColor.b = gui.property("#B:", 0.0f, envColor.b, 1.0f, 0.01f, 0.005f);
                        gui.popupEnd();
                    } 
                    else envColorPicker = false;
                }
                
                gui.layoutRowDynamic(25, 2);
                gui.label("Sun pitch:", NK_TEXT_LEFT);
                gui.slider(-180.0f, &sunPitch, 180.0f, 1.0f);
                
                gui.layoutRowDynamic(25, 2);
                gui.label("Sun turn:", NK_TEXT_LEFT);
                gui.slider(-180.0f, &sunTurn, 180.0f, 1.0f);
                gui.treePop();
            }
            
            if (gui.treePush(NK_TREE_NODE, "Material", NK_MAXIMIZED))
            {
                gui.layoutRowDynamic(25, 2);
                gui.checkboxLabel("Textures", &useTextures);
                
                gui.layoutRowDynamic(25, 2);
                gui.label("Diffuse color:", NK_TEXT_LEFT);
                if (gui.buttonColor(diffuseColor)) 
                    diffuseColorPicker = !diffuseColorPicker;
                
                if (diffuseColorPicker)
                {
                    NKRect s = NKRect(300, 100, 300, 350);
                    if (gui.popupBegin(NK_POPUP_STATIC, "Color", NK_WINDOW_CLOSABLE, s))
                    {
                        gui.layoutRowDynamic(180, 1); 
                        diffuseColor = gui.colorPicker(diffuseColor, NK_RGB);
                        gui.layoutRowDynamic(25, 1);
                        diffuseColor.r = gui.property("#R:", 0.0f, diffuseColor.r, 1.0f, 0.01f, 0.005f);
                        diffuseColor.g = gui.property("#G:", 0.0f, diffuseColor.g, 1.0f, 0.01f, 0.005f);
                        diffuseColor.b = gui.property("#B:", 0.0f, diffuseColor.b, 1.0f, 0.01f, 0.005f);
                        gui.popupEnd();
                    } 
                    else diffuseColorPicker = false;
                }
                
                gui.layoutRowDynamic(25, 1);
                roughness = gui.property("Roughness:", 0.0f, roughness, 1.0f, 0.01f, 0.005f);
                
                gui.layoutRowDynamic(25, 1);
                metallic = gui.property("Metallic:", 0.0f, metallic, 1.0f, 0.01f, 0.005f);
                gui.treePop();
            }
            
            /*
            if (gui.treePush(NK_TREE_NODE, "Options", NK_MINIMIZED))
            {
                gui.layoutRowDynamic(30, 2);
                if (gui.optionLabel("on", option == true)) option = true;
                if (gui.optionLabel("off", option == false)) option = false;
                gui.treePop();
            }
                
            if (gui.treePush(NK_TREE_NODE, "Input", NK_MINIMIZED))
            {
                static int len = 4;
                static char[256] buffer = "test";
                gui.layoutRowDynamic(35, 1);
                gui.editString(NK_EDIT_FIELD, buffer.ptr, &len, 255, null);
                gui.treePop();
            }
            */
        }
        gui.end();
    }
}
