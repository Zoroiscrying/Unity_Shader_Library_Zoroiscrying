# Unity_Shader_Library_Zoroiscrying
This is a shader library used for unity shader coding, pointing to different shader effects found from various sources. Several library topics may become public in the future. This project is mainly for personal study and lack the knowledge of code management(i.e., comprehensive comment / user guide) and formal name formatting.

The following showcase pictures and knowledge network are organized in my understanding of different categories of shaders, some references and cites will be listed. But most of the content will be covered in my personal markdown notes.

## Functions in Shaders

### 1 Step Functions

### 2 Value Range Manipulation

### 3 Noise / Hash

### 4 Projection Functions

### 5 Sin / Cos

## Geometry Related Shader

## Object VFX Related

#### 1 Crystal Shader

#### 2 Custom Light Flare Shape

#### 3 Dissolve Shader

#### 4 Foil Card Shader

#### 5 Hologram, Holofield, Force Field Shader

#### 6 Outline Shader

#### 7 Pickable / Interactable Object

#### 8 Space Orb Shader - Inspired by TFT

#### 9 Sparkle Glitter Shader

#### 10 Trace-On VFX - From Fate / Stay Night

#### 11 Trail VFX

#### 12 Vertex Displacement

## Particle VFX Related

## Screen Space Based Shaders

### Post Processing Shaders

#### 1 Post-Process Fog

#### 2 Post Process Volumetric Lighting

#### 3 Post Process Damaged FX

#### 4 Post Process Acceleration Effect

#### 5 VHS-Image Effect & Glitch

### Other Screen Space Approaches

#### 1 Depth Buffer Related

#### 2 Stencil Buffer Related

#### 3 TAA & FXAA

## Shading Models

#### 1 Cel Shading

#### 2 Flat Shading

#### 3 Gooch Shading

#### 4 NPRs

#### 5 PBR Shading

#### 6 SSS

## Sky Related

### 1 Skybox Shader

### 2 Volumetric Cloud Shader

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
  - Vegetation - Grass, Vines, Shrubs
  - Plant - Tree
  - Cloth - Non-physically-correct
  - Fur / Hair



### 2 Volumetric Lighting & Atmospheric Scattering

**References**

- 

**Showcase Pictures**

World-Space Ray-Marching Volumetric Lighting



Post-Processing Radial-Blur Volumetric Lighting



### 3 Deformable Snow Ground

### 4 Dynamic Weather System

### 5 Screen Space Particles

**References**

- 

### 6 Terrain Rendering System

### 7 Displaced Vegetation, Mesh, Hair, Fur, Card

### 8 Volumetric Cloud System

### 9 Water & Ocean Simulation & Rendering

## Custom RT Approaches

### 1 Snow / Grass Foot Trail

### 2 Fluid Simulation

## Rendering Technologies and Uses

### 1 Tessellation

### 2 Texture Blending

### 3 Parallax Mapping

## Shading Techniques

### 1 Color Ramp

### 2 Noise Based Texture Color Variation

### 3 Normal from Height Map



