using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode, RequireComponent(typeof(Light))]
public class SkyController : MonoBehaviour {
    [Header("Sky colors")]
    public bool overrideSkyColors;
    [GradientUsage(true)]
    public Gradient topColor;
    [GradientUsage(true)]
    public Gradient middleColor;
    [GradientUsage(true)]
    public Gradient bottomColor;

    [Header("Sun color")]
    public bool overrideSunColor;
    [GradientUsage(true)]
    public Gradient sunColor;

    [Header("Sun light color")]
    public bool overrideLightColor;
    public Gradient lightColor;

    [Header("Ambient sky color")]
    public bool overrideAmbientSkyColor;
    [GradientUsage(true)]
    public Gradient ambientSkyColor;

    [Header("Clouds color")]
    public bool overrideCloudsColor;
    [GradientUsage(true)]
    public Gradient cloudsColor;

    [Header("Debug scrub")]
    public bool useSrub = false;
    [Range(0.0f, 1.0f)]
    public float scrub;

    private Light sun;

    public Light Sun {
        get {
            if (sun == null) {
                sun = GetComponent<Light>();
            }
            return sun;
        }
    }

    private Material skyMaterial;

    public Material SkyMaterial {
        get {
            if (skyMaterial == null) {
                skyMaterial = RenderSettings.skybox;
            }
            return skyMaterial;
        }
    }

    public void OnValidate() {
        if (useSrub) {
            UpdateGradients(scrub);
        }
    }

    private void Update() {
        if (!useSrub && Sun.transform.hasChanged) {
            float pos = Vector3.Dot(Sun.transform.forward.normalized, Vector3.up) * 0.5f + 0.5f;
            UpdateGradients(pos);
        }
    }

    public void UpdateGradients(float pos) {
        if (overrideSkyColors) {
            SkyMaterial.SetColor("_ColorTop", topColor.Evaluate(pos));
            SkyMaterial.SetColor("_ColorMiddle", middleColor.Evaluate(pos));
            SkyMaterial.SetColor("_ColorBottom", bottomColor.Evaluate(pos));
        }
        if (overrideSunColor) {
            SkyMaterial.SetColor("_SunColor", sunColor.Evaluate(pos));
        }
        if (overrideLightColor) {
            Sun.color = lightColor.Evaluate(pos);
        }
        if (overrideAmbientSkyColor) {
            if (RenderSettings.ambientMode == UnityEngine.Rendering.AmbientMode.Trilight) {
                RenderSettings.ambientSkyColor = topColor.Evaluate(pos);
                RenderSettings.ambientEquatorColor = middleColor.Evaluate(pos);
                RenderSettings.ambientGroundColor = bottomColor.Evaluate(pos);
            } else if (RenderSettings.ambientMode == UnityEngine.Rendering.AmbientMode.Flat) {
                RenderSettings.ambientSkyColor = ambientSkyColor.Evaluate(pos);
            }
        }
        if (overrideCloudsColor) {
            SkyMaterial.SetColor("_CloudsColor", cloudsColor.Evaluate(pos));
        }
    }
}