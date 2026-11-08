# Menu pages' C++: `python wcmods.py cpp build <this mod>` builds it into dlls/main.dll. wcmods_mod (from
# wcmods/cpp_sdk/WCMods.cmake) makes the DLL, linked against UE4SS, with WCMods.hpp and src/ on the include path.
# docs/SDK.md, "C++ mods"; README.md here says what it gives the pages.
wcmods_mod(${WCMODS_TARGET}
    src/main.cpp
    src/calls.cpp
)
