using UnityEngine;

public class DefineCheck : MonoBehaviour
{
    void Start()
    {
#if URP_COMPATIBILITY_MODE
        Debug.Log("URP_COMPATIBILITY_MODE: ON");
#else
        Debug.Log("URP_COMPATIBILITY_MODE: OFF");
#endif
    }
}