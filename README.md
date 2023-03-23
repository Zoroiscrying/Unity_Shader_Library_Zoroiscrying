# Unity_Shader_Library_Zoroiscrying
This is a shader library used for unity shader coding, pointing to different shader effects found from various sources. Several library topics may become public in the future. This project is mainly for personal study and lack the knowledge of code management(i.e., comprehensive comment / user guide) and formal name formatting.

The following showcase pictures and knowledge network are organized in my understanding of different categories of shaders, some references and cites will be listed. But most of the content will be covered in my personal markdown notes.

See https://www.youtube.com/watch?v=aasnYKazO2Q for my TA/Rendering showreel and other bits of progress of this repository.

## Functions in Shaders

### 1 Step Functions

### 2 Value Range Manipulation

### 3 Noise / Hash

### 4 Projection Functions

### 5 Sin / Cos

## Geometry Related Shader

## Object VFX Related

#### 1 Crystal Shader

- Crystal Color Ramp
- Opaque Texture Reflection - RGB Split effect
![Crystal_Shader](Resources/Showcases/OBJ_VFX/Crystal_Shader.jpg)
![Crystal_Shader_2](Resources/Showcases/OBJ_VFX/Crystal_Shader_2.jpg)

#### 2 Custom Light Flare Shape
- Reference - Genshin Impact 渊下宫 / Zone Zero / Kejiro's PPS Light Streak

#### 3 Dissolve Shader

- Distance / Position / UV based Dissolve Factor calculation
- Dissolve Edge and Color
- Noise Dissolve Edge fluctuation
- Runtime implementation
  - Material Property Block - Object Position Property Binder
![Dissolve_1](Resources/Showcases/OBJ_VFX/Dissolve_Shader_1.jpg)
![Dissolve_2](Resources/Showcases/OBJ_VFX/Dissolve_Shader_2.jpg)
![Dissolve_3](Resources/Showcases/OBJ_VFX/Dissolve_Shader_3.jpg)

#### 4 Foil Card Shader

- TBC - Magic: The Gathering / Legends of Runeterra look

#### 5 Hologram, Holofield, Force Field Shader

- Noise based vertex displacement (high frequency and low frequency)
- World / Object / Screen Position based scan line (thin and thick)
- Fresnel Inner Outline
- Depth based edge detection and noise based variation
- Animation Process Mask map usage
![Hologram](Resources/Showcases/OBJ_VFX/Hologram_Shader.jpg)
![HoloField](Resources/Showcases/OBJ_VFX/Holofield_Shader.jpg)

#### 6 Outline Shader

- 

#### 7 Pickable / Interactable Object

#### 8 Space Orb Shader - Inspired by TFT

- Screen Space UV Quad Formation and 2D Noise Texture distortion
- 3D Noise based shinning glitter
- Fresnel + Noise achieving flowing inner outline

![Space_Orb](Resources/Showcases/OBJ_VFX/Space_Orb_Shader.jpg)


#### 9 Sparkle Glitter Shader

- TBC - Journey / Witness desert look

#### 10 Trace-On VFX - From Fate / Stay Night

- TBC

#### 11 Trail VFX

- TBC

#### 12 Vertex Displacement
- Noise-based displacement variation
- Distance based / Position based / Anime Goosebump Mockup

![Vertex_Displacement](Resources/Showcases/OBJ_VFX/Displacement_Shader_1.jpg)
Ref:
![Anime_Displacement_Ref](Resources/Showcases/OBJ_VFX/Displacement_Ref_1.jpg)

## Particle VFX Related

## Screen Space Based Shaders

### Post Processing Shaders

#### 1 Post-Process Fog

#### 2 Post Process Volumetric Lighting

- Post Processing Light Shaft
  - Occlusion Texture generation (only skybox kept)
  - Radial image blur achieving light shaft leaking effect
    - Noise offset turning pattern into noise

![Radial_blur_volumetric_light](Resources/Showcases/Screen_Space_Shaders/Post_Process_Image_Blur_Volumetric_Light.jpg)


#### 3 Post Process Damaged FX

#### 4 Post Process Acceleration Effect

- Animated Speed Lines
- Good reference - Apex: Legends;

![Animated_Speedline](Resources/Showcases/Screen_Space_Shaders/Animated_Speedline.jpg)

#### 5 VHS-Image Effect & Glitch

### Other Screen Space Approaches

#### 1 Depth Buffer Related

- SSAO
- World Position Rebuild
- Not implemented yet.

#### 2 Stencil Buffer Related

- Portal
- Mooncage

#### 3 TAA & FXAA

## Shading Models

#### 1 Cel Shading

- Genshin Impact Style Cel Shading, Lightmap guided, Color ramp controlled (lacks face ramp control and hair specular map usage, didn't use screen space rim light).
  - Outline pass - Screen Space thickness, View space normal extrusion

![Genshin_Cel_1](Resources/Showcases/Shading_Model/Genshin_Impact_Cel_Shading_1.jpg)
![Genshin_Cel_2](Resources/Showcases/Shading_Model/Genshin_Impact_Cel_Shading_2.jpg)

- PBR Based Cel Shading
  - Diffuse, Specular falloff and ramp control



#### 2 Flat Shading

#### 3 Gooch Shading

#### 4 NPRs

- Matcap shading

![Mapcap_Shading](Resources/Showcases/Shading_Model/Matcap_Shading.jpg)

- NRP Shading
  - Multiple ramp area control
  - Diffuse, Specular, Shadow area control (for various artistic styles)
  - Specular intensity control (the smoothstep function breaks the energy conservation, thus need to tweak the value to achieve proper appearance)
  - Halftone step (UV Space / Screen Space)

![NPR_Shading_1](Resources/Showcases/Shading_Model/NPR_Shading_1.jpg)
![NPR_Shading_2](Resources/Showcases/Shading_Model/NPR_Shading_2.jpg)
![NPR_Shading_3](Resources/Showcases/Shading_Model/NPR_Shading_3.jpg)
![NPR_Shading_4](Resources/Showcases/Shading_Model/NPR_Shading_4.jpg)

#### 5 PBR Shading

- Todo: Anisotropic Specular Calculation
- Todo: UE approach of spherical-shape light / line-shape light (representative point)
- Todo: RBF area light approach
- Todo: HDRP shader understanding

#### 6 SSS
- Todo: Fake SSS with thickness map
- Todo: Human Skin SSS rendering
- 

## Sky Related

### 1 Skybox Shader

- Reference
  - https://medium.com/@jannik_boysen/procedural-skybox-shader-137f6b0cb77c
  - https://www.patreon.com/posts/making-stylized-27402644
  - https://halisavakis.com/my-take-on-shaders-sky-shader/
- Sun and Moon SDF based Rendering
- Texture / 3D Noise based Star rendering
- Texture Cloud Rendering
  - Todo: multiple sampling achieving cloud thickness feeling
- Sky dome color ramp control
  - Todo: add atmospheric scattering colorization 

![Stylized_Skybox_1](Resources/Showcases/Sky_Related/Stylized_Skybox_1.jpg)

### 2  Fake Volumetric Cloud Shader

- Fake volumetric layer cloud - See: https://github.com/Zoroiscrying/UnityInteractableWater-Grass-Wind_URP
- Todo: Ray-marched volumetric cloud

## Environment Shading Techs

## Shader Systems

### 1 Global Wind 3D (Inspired by God of War Implementation)

**References**

- [Wind Simulation in God of War - YouTube](https://www.youtube.com/watch?v=dDgyBKkSf7A&t=1460s)
- [graphics.cs.cmu.edu/nsp/course/15-464/Fall09/papers/StamFluidforGames.pdf](http://graphics.cs.cmu.edu/nsp/course/15-464/Fall09/papers/StamFluidforGames.pdf)
- [Interactive Wind and Vegetation in 'God of War' - YouTube](https://www.youtube.com/watch?v=MKX45_riWQA)
- [Between Tech and Art: The Vegetation of Horizon Zero Dawn - YouTube](https://www.youtube.com/watch?v=wavnKZNSYqU)

**Showcase Pictures**

(Work in progress on artistic showcases and dynamic vegetations...)

Global Wind 3D Scene Debug

- Based on `DrawMeshInstancedIndirect`

<img src="Resources/Global Wind 3D/GlobalWind3DWindDebug1.jpg" alt="GlobalWind3DWindDebug1" style="zoom:80%;" />

Global Wind 2D Texture Slice Debug

- Based on Unity Post Processing and Custom PPS Render Pass

<img src="Resources/Global Wind 3D/GlobalWind3DWindDebug2.jpg" alt="GlobalWind3DWindDebug2" style="zoom:80%;" />

Wind Contributor Objects

- Shapes - Box, Cylinder, Sphere
- Velocity Calculation Type - Fixed, Point-based, Axis-Distance-Based

<img src="Resources/Global Wind 3D/GlobalWind3DWindDebug3.jpg" alt="GlobalWind3DWindDebug1" style="zoom:60%;" /><img src="Resources/Global Wind 3D/GlobalWind3DWindDebug4.jpg" alt="GlobalWind3DWindDebug1" style="zoom:50%;" /><img src="Resources/Global Wind 3D/GlobalWind3DWindDebug5.jpg" alt="GlobalWind3DWindDebug1" style="zoom:50%;" />

Wind Receivers (On Progress)

- Planning
  - Vegetation - Grass, Vines, Shrubs (On-Going)
  - Plant - Tree
  - Cloth - Non-physically-correct
  - Fur / Hair
- Future Improvements
  - Box Contributor seems to have incorrect influence on the wind texture.
 

### 2 Volumetric Lighting & Atmospheric Scattering

**References**

- https://www.slideshare.net/BenjaminGlatzel/volumetric-lighting-for-many-lights-in-lords-of-the-fallen
- [Physically Based and Unified Volumetric Rendering in Frostbite](https://www.slideshare.net/DICEStudio/physically-based-and-unified-volumetric-rendering-in-frostbite)
- [GitHub - ArthurBrussee/Vapor at master](https://github.com/ArthurBrussee/Vapor/tree/master)
- [Volumetric lights - Alexandre Pestana](http://www.alexandre-pestana.com/volumetric-lights/)
- [https://bartwronski.files.wordpress.com/2014/08/bwronski_volumetric_fog_siggraph2014.pdf](https://bartwronski.files.wordpress.com/2014/08/bwronski_volumetric_fog_siggraph2014.pdf)


**Showcase Pictures**

World-Space Ray-Marching Volumetric Lighting
- World Space Camera Ray-march, Single Scattering Calculation
- Down-sample and up-sample reducing GPU cost
- Noise offset turning pattern into noise
- Bilateral Blur keeping sharp edge
- Gaussian Blur reducing light shaft edge artifact

![Volumetric_Lighting_Single_Scattering](Resources/Showcases/Screen_Space_Shaders/Camera_Space_Single_Scattering_Volumetric_Light.jpg)

Post-Processing Radial-Blur Volumetric Lighting
![Radial_blur_volumetric_light](Resources/Showcases/Screen_Space_Shaders/Post_Process_Image_Blur_Volumetric_Light.jpg)

- TODO: Last of Us 2 volumetric lighting
  - Frustum Voxel 3D scattering & decay texture / integration texture
  - Various light shape's precalculated integration result
  - Shadow map implementation for various light shapes
  - Down-sampling and TAA support for volumetric lighting result
- Useful code reference
  - Unity Adam showcase volumetric lighting
  - Unity HDRP Volumetric lighting implementation

### 3 Deformable Snow Ground

![DeformableSnow](Resources/DeformableSnowAndSand/DeformableSnow1.png)
![SnowGrainParticleShaderGraph](Resources/DeformableSnowAndSand/SnowGrainParticle.png)

- Algorithm by: Tomb Raider: Rise (Deferred Snow Deformation in Rise of the Tomb Raider by Michels and Sikachev)
- Todo
  - Add support for Vertical-Sliding-Window
  - Create a more immersive showcase combining the GPU snow particles implementation.
  - Adoption of various snow deformers (currently only one rounded type)
- Personal Concern and Possible Improvements
  - Comparison with Traditional Height-Map-Based Snow Deformation
    - Pros
      - Suport for overlapping snow deformation (stepping snow on a bridge will only cause deformation on the bridge but not on the snow below the bridge)
      - Better snow deformation and edge curve calculation due to deferred snow deformation.
    - Cons
      - Extra calculation when pack and extract bit data.
      - Limited Precision for snow fill process.

### 4 Dynamic Weather System

- Todo: Do some research ^^.

### 5 Screen Space Particles

- Last of Us 2 screen particles approach.

**References**

- https://dl.acm.org/doi/fullHtml/10.1145/3388767.3407349

### 6 Terrain Rendering System

### 7 Displaced Vegetation, Mesh, Hair, Fur, Card

**References**

- https://www.youtube.com/watch?v=MKX45_riWQA GDC talk by Sean Feeley
- Three layers of movement
  - Wind-Direction Displacement based on Global Wind Texture.
  - Local Spherical Noise based on Wind intensity.
  - Stateful sway (displacement data stored in Buffer and processed in Compute Shader to achieve persistent movement)
    - Basic Process (Every wind receiver can be treated as a single spring with a fixed location in the world, we then can use a spring model to calculate the force, hence acceleration, velocity, and displaced position in the world)
- Future Improvements
  - Stateful Tree Implementation.
  - Integrate Global Wind into refractored Grass Shader.
  - Improve the movement shader code to match real-world wind speed and object movement.
  - Improvement of editor scripts (maybe improvement on the GlobalWind3D Manager editor as well, utilizing Unity's uxml system (also serving as a learning process))

<img src="Resources/Global Wind 3D/GlobalWind3D_Vegetation_1.png" alt="GlobalWind3D_Vegetation_1" style="zoom:80%;" />


### 8 Volumetric Cloud System

- Todo: Horizon: Zero Dawn volumetric cloud solution

### 9 Water & Ocean Simulation & Rendering

- Stylized Water / Ocean Shader
  - Todo: Jacobian water foam calculation
  - Todo: RT + Particle system water foam and interaction (stylized)
  - Todo: Underwater Post Process / Midwater look through effect (Maybe use stencil + post processing / world space near-camera water surface calculation + post processing)
    - Another possible solution: render a depth map of the water top down above the camera, while in post-process, compare the screen pixel's vertical position in the world with the current water's height based on the depth map rendered (sounds like it, but I'm not sure). This solution supports Gerstner waves because it samples the water height after displacement.
    - And Another one: render a near-plane dynamic mesh by sampling the water height at sepecific locations, render this mesh onto a low-res texture with a simple blur (render as white, background black, thus generating a mask texture at screen space). This solution does not support Gerstner waves, as Gerstner waves would change XZ position of water, causing the tracing of a height change on a fixed XZ point impossible (or extremely difficult).
    - Actually, due to the consideration above, I would suggest using FFT waves for water movement (pure height map solution, only vertical movement).
  - Depth and ramp based water colorization
  - Gerstner / Sine wave and normal re-calculation
  - Edge foam
  - Water reflection and refraction

![Stylized_Ocean_1](Resources/Ocean%20and%20Water/Stylized_Ocean_1.jpg)
![Stylized_Ocean_2](Resources/Ocean%20and%20Water/Stylized_Ocean_2.jpg)
![Stylized_Ocean_3](Resources/Ocean%20and%20Water/Stylized_Ocean_3.jpg)

- Todo: FFT-based Realistic Ocean Shaders (Praise Horizon: Forbidden West and Assassin's Creed: Odyssey)
- Todo: Various Ocean simulations (Heightfield water simulation especially)

## Custom RT Approaches

### 1 Snow / Grass Foot Trail

### 2 Fluid Simulation

## Rendering Technologies and Uses

### 1 Tessellation

- Used in:
  - Stylized Water / Ocean Shader

### 2 Texture Blending

**References**

- 

### 3 Parallax Mapping

**References**

- Catlike coding: https://catlikecoding.com/unity/tutorials/rendering/part-20/

## Shader Techniques

### 1 Color Ramp

### 2 Noise Based Texture Color Variation

**References**

- 

### 3 Normal from Height Map

**References**

- 



