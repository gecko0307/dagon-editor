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
import std.random;
import dagon;

class Editor: Scene
{
    Game game;
    LoadingScreen loadingScreen;

    FontAsset aFont;

    OBJAsset aMeshGun;
    TextureAsset aTexGunAlbedo;
    TextureAsset aTexGunNormal;
    TextureAsset aTexGunRoughness;
    TextureAsset aTexGunMetallic;

    ImageAsset aHeightmap;
    
    TextureAsset aSplatmapPavement;
    TextureAsset aSplatmapGrass;
    
    TextureAsset aTexDesertAlbedo;
    TextureAsset aTexDesertNormal;
    TextureAsset aTexGrassAlbedo;
    TextureAsset aTexGrassNormal;
    TextureAsset aTexPavementAlbedo;
    TextureAsset aTexPavementNormal;
    
    //TextureAsset aEnvmap;
    
    ImageAsset aTexSkyFront;
    ImageAsset aTexSkyBack;
    ImageAsset aTexSkyLeft;
    ImageAsset aTexSkyRight;
    ImageAsset aTexSkyTop;
    ImageAsset aTexSkyBottom;
    
    TextureAsset aTexDecalLeaves;

    OBJAsset aBushHi;
    OBJAsset aBushLow;
    TextureAsset aBush;

    Camera camera;
    FreeviewComponent freeview;

    Light sun;
    Entity eSky;
    RayleighShader rayleighShader;
    bool useSky = false;
    Cubemap envCubemap;

    ShapeSphere lightSphere;

    Entity eTerrain;
    Entity eGun;

    FreeTypeFont font;
    Entity text;
    TextLine infoText;

    NuklearGUI gui;
    bool envColorPicker = false;
    Color4f envColor = Color4f(0.8f, 0.8f, 1.0f, 1.0f);
    bool sunColorPicker = false;
    Color4f sunColor = Color4f(1.0f, 0.7f, 0.5f, 1.0f);

    float sunPitch = -25.0f;
    float sunTurn = 135.0f;

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

        aMeshGun = addOBJAsset("data/cerberus/cerberus.obj");
        aTexGunAlbedo = addTextureAsset("data/cerberus/cerberus-albedo.png");
        aTexGunNormal = addTextureAsset("data/cerberus/cerberus-normal.png");
        aTexGunRoughness = addTextureAsset("data/cerberus/cerberus-roughness.png");
        aTexGunMetallic = addTextureAsset("data/cerberus/cerberus-metallic.png");

        aHeightmap = addImageAsset("data/terrain/heightmap.png");
        aSplatmapPavement = addTextureAsset("data/terrain/splatmap-pavement.png");
        aSplatmapGrass = addTextureAsset("data/terrain/splatmap-grass.png");
        
        aTexDesertAlbedo = addTextureAsset("data/terrain/desert-albedo.png");
        aTexDesertNormal = addTextureAsset("data/terrain/desert-normal.png");
        
        aTexPavementAlbedo = addTextureAsset("data/terrain/pavement-albedo.png");
        aTexPavementNormal = addTextureAsset("data/terrain/pavement-normal.png");
        
        aTexGrassAlbedo = addTextureAsset("data/terrain/grass-albedo.png");
        aTexGrassNormal = addTextureAsset("data/terrain/grass-normal.png");
        
        //aEnvmap = addTextureAsset("data/TropicalRuins_Env.hdr");
        
        aTexSkyFront = addImageAsset("data/skybox/sky_front.png");
        aTexSkyBack = addImageAsset("data/skybox/sky_back.png");
        aTexSkyLeft = addImageAsset("data/skybox/sky_left.png");
        aTexSkyRight = addImageAsset("data/skybox/sky_right.png");
        aTexSkyTop = addImageAsset("data/skybox/sky_top.png");
        aTexSkyBottom = addImageAsset("data/skybox/sky_bottom.png");

        aBushHi = addOBJAsset("data/bush/bush-hi.obj");
        aBushLow = addOBJAsset("data/bush/bush-low.obj");
        aBush = addTextureAsset("data/bush/bush.png");
        
        aTexDecalLeaves = addTextureAsset("data/decals/leaves1.png");
    }

    override void onLoad(Time t, float progress)
    {
        loadingScreen.update(t, progress);
        loadingScreen.render();
    }

    override void afterLoad()
    {
        envCubemap = addCubemap(1024);
        //envCubemap.fromEquirectangularMap(aEnvmap.texture);
        envCubemap.setFaceImage(CubeFace.PositiveZ, aTexSkyFront.image);
        envCubemap.setFaceImage(CubeFace.NegativeZ, aTexSkyBack.image);
        envCubemap.setFaceImage(CubeFace.PositiveX, aTexSkyRight.image);
        envCubemap.setFaceImage(CubeFace.NegativeX, aTexSkyLeft.image);
        envCubemap.setFaceImage(CubeFace.PositiveY, aTexSkyTop.image);
        envCubemap.setFaceImage(CubeFace.NegativeY, aTexSkyBottom.image);
        environment.ambientMap = envCubemap;

        camera = addCamera();
        freeview = New!FreeviewComponent(eventManager, camera);
        freeview.zoom(-20);
        freeview.pitch(-30.0f);
        freeview.turn(10.0f);
        game.renderer.activeCamera = camera;

        game.deferredRenderer.ssaoEnabled = true;
        game.deferredRenderer.ssaoPower = 6.0;
        game.postProcessingRenderer.motionBlurEnabled = true;
        game.postProcessingRenderer.glowEnabled = true;
        game.postProcessingRenderer.fxaaEnabled = true;
        game.postProcessingRenderer.motionBlurFramerate = 30;

        sun = addLight(LightType.Sun);
        sun.position.y = 50.0f;
        sun.shadowEnabled = true;
        sun.energy = 10.0f;
        sun.scatteringEnabled = true;
        sun.color = sunColor;

        lightSphere = New!ShapeSphere(1.0f, 24, 16, false, assetManager);
        //addLightBall(Vector3f(0, 8, -8), Color4f(1.0, 0.5, 0.0, 1.0), 10.0f, 1.0f, 20.0f);
        //addLightBall(Vector3f(0, 8, 8),  Color4f(0.0, 0.5, 1.0, 1.0), 10.0f, 1.0f, 20.0f);

        eSky = addEntity();
        eSky.layer = EntityLayer.Background;
        auto psync = New!PositionSync(eventManager, eSky, camera);
        eSky.drawable = New!ShapeBox(Vector3f(1.0f, 1.0f, 1.0f), assetManager);
        eSky.scaling = Vector3f(100.0f, 100.0f, 100.0f);
        eSky.material = addMaterial();
        rayleighShader = New!RayleighShader(assetManager);
        eSky.material.depthWrite = false;
        eSky.material.culling = false;
        eSky.material.diffuse = envCubemap;

        eTerrain = addEntity();
        eTerrain.dynamic = false;
        eTerrain.position = Vector3f(-64, 0, -64);
        eTerrain.material = addMaterial();
        
        eTerrain.material.diffuse = aTexDesertAlbedo.texture;
        eTerrain.material.textureScale = Vector2f(50, 50);
        eTerrain.material.normal = aTexDesertNormal.texture;
        eTerrain.material.roughness = 0.8f;

        eTerrain.material.diffuse2 = aTexGrassAlbedo.texture;
        eTerrain.material.splatmap2 = aSplatmapGrass.texture;
        eTerrain.material.textureScale2 = Vector2f(100, 100);
        eTerrain.material.normal2 = aTexGrassNormal.texture;
        eTerrain.material.roughness2 = 1.0f;
        
        eTerrain.material.diffuse3 = aTexPavementAlbedo.texture;
        eTerrain.material.splatmap3 = aSplatmapPavement.texture;
        eTerrain.material.textureScale3 = Vector2f(100, 100);
        eTerrain.material.normal3 = aTexPavementNormal.texture;
        eTerrain.material.roughness3 = 0.5f;

        auto heightmap = New!ImageHeightmap(aHeightmap.image, 30.0f, assetManager);
        auto terrain = New!Terrain(512, 64, heightmap, assetManager);
        eTerrain.drawable = terrain;
        eTerrain.scaling = Vector3f(0.25f, 0.25f, 0.25f);

        eGun = addEntity();
        eGun.position.y = 14.0f;
        eGun.drawable = aMeshGun.mesh;
        eGun.material = addMaterial();
        eGun.material.diffuse = aTexGunAlbedo.texture;
        eGun.material.normal = aTexGunNormal.texture;
        eGun.material.roughness = aTexGunRoughness.texture;
        eGun.material.metallic = aTexGunMetallic.texture;
        eGun.material.energy = 2.0f;
        eGun.visible = false;
        diffuseColor = Color4f(0.5f, 0.5f, 0.5f, 1.0f);

        auto mBushHi = addMaterial();
        mBushHi.diffuse = aBush.texture;
        mBushHi.roughness = 1;
        mBushHi.specularity = 0;
        auto mBushLow = addMaterial();
        mBushLow.diffuse = aBush.texture;
        mBushLow.culling = false;
        mBushLow.roughness = 1;
        mBushLow.specularity = 0;
        mBushLow.sphericalNormal = true;

        auto lod = New!LODDrawable(assetManager);
        lod.addLevel(aBushHi.mesh, mBushHi, 0.0f, 50.0f, 0.0f);
        lod.addLevel(aBushLow.mesh, mBushLow, 50.0f, 500.0f, 0.0f);
        Vector3f center = Vector3f(0.0f, 0.0f, 0.0f);

        foreach(i; 0..100)
        {
            auto eLod = addEntity();
            eLod.drawable = lod;
            eLod.position = center + randomUnitVector3!float() * uniform(2.0f, 50.0f);
            eLod.position.y = terrain.getHeight(eTerrain, eLod.position);
            eLod.scale(3);
        }
        
        auto leavesDecalMaterial = addMaterial();
        leavesDecalMaterial.diffuse = aTexDecalLeaves.texture;
        leavesDecalMaterial.blending = Transparent;
        leavesDecalMaterial.depthWrite = false;
        leavesDecalMaterial.culling = false;
        leavesDecalMaterial.outputColor = true;
        leavesDecalMaterial.outputNormal = false;
        leavesDecalMaterial.outputPBR = false;
        
        auto decal = addDecal();
        decal.position = Vector3f(20, 0, 0);
        decal.scale(2.0f);
        decal.position.y = terrain.getHeight(eTerrain, decal.position);
        decal.material = leavesDecalMaterial;

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

    Light addLightBall(Vector3f pos, Color4f color, float energy, float areaRadius, float volumeRadius)
    {
        auto light = addLight(LightType.AreaSphere);
        light.castShadow = false;
        light.position = pos;
        light.color = color;
        light.energy = energy;
        light.radius = areaRadius;
        light.volumeRadius = volumeRadius;

        auto lightGeom = addEntity(light);
        lightGeom.drawable = lightSphere;
        lightGeom.scaling = Vector3f(areaRadius, areaRadius, areaRadius);
        lightGeom.material = addMaterial();
        lightGeom.material.diffuse = color;
        lightGeom.material.emission = color;
        lightGeom.material.energy = energy;

        return light;
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
        sun.color = sunColor;

        rayleighShader.sunDirection = -sun.rotation.rotate(Vector3f(0.0f, 0.0f, 1.0f));
        if (useSky)
            eSky.material.shader = rayleighShader;
        else
            eSky.material.shader = null;

        if (!useTextures)
        {
            eGun.material.diffuse = diffuseColor;
            eGun.material.roughness = roughness;
            eGun.material.metallic = metallic;
        }
        else
        {
            eGun.material.diffuse = aTexGunAlbedo.texture;
            eGun.material.roughness = aTexGunRoughness.texture;
            eGun.material.metallic = aTexGunMetallic.texture;
        }
    }

    override void onKeyDown(int key)
    {
        if (key == KEY_ESCAPE)
            application.exit();
        else if (key == KEY_BACKSPACE)
            gui.inputKeyDown(NK_KEY_BACKSPACE);
        else if (key == KEY_DELETE)
            gui.inputKeyDown(NK_KEY_DEL);
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

    /*
    override void onDropFile(string filename)
    {
        writeln(filename);
        assetManager.reloadAsset(aEnvmap, filename);

        if (envCubemap)
            assetManager.deleteOwnedObject(envCubemap);

        envCubemap = New!Cubemap(1024, assetManager);
        envCubemap.fromEquirectangularMap(aEnvmap.texture);

        environment.ambientMap = envCubemap;
        eSky.material.diffuse = envCubemap;
    }
    */

    void updateMenu()
    {
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
    }

    void updateRenderTab()
    {
        if (gui.treePush(NK_TREE_NODE, "Render", NK_MAXIMIZED))
        {
            gui.layoutRowDynamic(30, 2);
            gui.label("Output:", NK_TEXT_LEFT);
            auto oldOutputMode = game.deferredRenderer.outputMode;
            game.deferredRenderer.outputMode =
                cast(DebugOutputMode)gui.comboString(
                    "Radiance\0Albedo\0Normal\0Position\0Roughness\0Metallic\0Occlusion",
                    game.deferredRenderer.outputMode, 7, 25, NKVec2(120, 250));
            if (game.deferredRenderer.outputMode != oldOutputMode)
                writeln("Output mode: ", game.deferredRenderer.outputMode);

            gui.layoutRowDynamic(25, 1);
            game.deferredRenderer.ssaoSamples = gui.property("AO samples:", 1, game.deferredRenderer.ssaoSamples, 25, 1, 1);
            game.deferredRenderer.ssaoRadius = gui.property("AO radius:", 0.05f, game.deferredRenderer.ssaoRadius, 1.0f, 0.01f, 0.005f);
            game.deferredRenderer.ssaoPower = gui.property("AO power:", 0.0f, game.deferredRenderer.ssaoPower, 10.0f, 0.01f, 0.01f);
            game.deferredRenderer.ssaoDenoise = gui.property("AO denoise:", 0.0f, game.deferredRenderer.ssaoDenoise, 1.0f, 0.01f, 0.01f);

            gui.layoutRowDynamic(25, 1);
            game.postProcessingRenderer.glowThreshold = gui.property("Glow threshold:", 0.0f, game.postProcessingRenderer.glowThreshold, 1.0f, 0.01f, 0.005f);
            game.postProcessingRenderer.glowIntensity = gui.property("Glow intensity:", 0.0f, game.postProcessingRenderer.glowIntensity, 1.0f, 0.01f, 0.005f);

            gui.layoutRowDynamic(25, 1);
            game.postProcessingRenderer.glowRadius = gui.property("Glow radius:", 1, game.postProcessingRenderer.glowRadius, 10, 1, 1);

            gui.layoutRowDynamic(30, 2);
            gui.label("Tonemapper:", NK_TEXT_LEFT);
            game.postProcessingRenderer.tonemapper =
                cast(Tonemapper)gui.comboString(
                    "None\0Reinhard\0Hable\0ACES",
                    game.postProcessingRenderer.tonemapper, 4, 25, NKVec2(120, 200));

            gui.layoutRowDynamic(25, 1);
            game.postProcessingRenderer.exposure = gui.property("Exposure:", 0.0f, game.postProcessingRenderer.exposure, 2.0f, 0.01f, 0.005f);

            gui.treePop();
        }
    }

    void updateEnvironmentTab()
    {
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
            gui.label("Sun color:", NK_TEXT_LEFT);
            if (gui.buttonColor(sunColor))
                sunColorPicker = !sunColorPicker;
            if (sunColorPicker)
            {
                NKRect s = NKRect(300, 100, 300, 350);
                if (gui.popupBegin(NK_POPUP_STATIC, "Color", NK_WINDOW_CLOSABLE, s))
                {
                    gui.layoutRowDynamic(180, 1);
                    sunColor = gui.colorPicker(sunColor, NK_RGB);
                    gui.layoutRowDynamic(25, 1);
                    sunColor.r = gui.property("#R:", 0.0f, sunColor.r, 1.0f, 0.01f, 0.005f);
                    sunColor.g = gui.property("#G:", 0.0f, sunColor.g, 1.0f, 0.01f, 0.005f);
                    sunColor.b = gui.property("#B:", 0.0f, sunColor.b, 1.0f, 0.01f, 0.005f);
                    gui.popupEnd();
                }
                else sunColorPicker = false;
            }

            gui.layoutRowDynamic(25, 1);
            gui.label("Rayleigh sky:", NK_TEXT_LEFT);
            gui.layoutRowDynamic(25, 2);
            if (gui.optionLabel("on", useSky == true)) useSky = true;
            if (gui.optionLabel("off", useSky == false)) useSky = false;

            gui.layoutRowDynamic(25, 2);
            gui.label("Sun pitch:", NK_TEXT_LEFT);
            gui.slider(-180.0f, &sunPitch, 180.0f, 0.01f);

            gui.layoutRowDynamic(25, 2);
            gui.label("Sun turn:", NK_TEXT_LEFT);
            gui.slider(-180.0f, &sunTurn, 180.0f, 0.01f);

            gui.layoutRowDynamic(25, 2);
            gui.label("Sun energy:", NK_TEXT_LEFT);
            gui.slider(0.0f, &sun.energy, 50.0f, 0.01f);

            gui.layoutRowDynamic(25, 2);
            int sc = sun.scatteringEnabled;
            gui.checkboxLabel("Volumetric light", &sc);
            sun.scatteringEnabled = cast(bool)sc;
            gui.layoutRowDynamic(25, 2);
            gui.label("Scattering:", NK_TEXT_LEFT);
            gui.slider(0.0f, &sun.scattering, 1.0f, 0.01f);
            gui.layoutRowDynamic(25, 2);
            gui.label("Medium density:", NK_TEXT_LEFT);
            gui.slider(0.0f, &sun.mediumDensity, 1.0f, 0.01f);

            gui.treePop();
        }
    }

    void updateMaterialTab()
    {
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
    }

    void updatePropertiesPanel()
    {
        if (gui.begin("Properties", NKRect(0, 40, 300, eventManager.windowHeight - 40), NK_WINDOW_TITLE))
        {
            updateRenderTab();
            updateEnvironmentTab();
            updateMaterialTab();

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

    void updateUserInterface(Time t)
    {
        gui.update(t);
        updateMenu();
        updatePropertiesPanel();
    }
}
