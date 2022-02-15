namespace ZoroiscryingUnityShaderLibrary.Runtime.MaterialBinder
{
    public interface IBindableComponent<T>
    {
        T ComponentValue
        {
           get;
        }
    }
}