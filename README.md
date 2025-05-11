# Qt to AppImage Action

 A GitHub Action that converts a Qt application built and installed into an AppImage 

## Usage

```yaml
- name: Build AppImage
  uses: Kidev/qt-appimage@v1
  with:
    install_folder: './install'   # Required: Path to folder where Qt installed your project
    app_name: 'MyApp'             # Optional: App name (deduced from binary if not set)
    comment: 'My awesome Qt app'  # Optional: Desktop entry comment
    category: 'Graphics'          # Optional: Desktop category (default: Utility)
    icon: 'path/to/icon.png'      # Optional: Path to icon file
    binary: 'myapp'               # Optional: Binary name (auto-detected if not set)
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `install_folder` | Folder with your Qt app installed | Yes | - |
| `app_name` | Application name | No | Deduced from binary |
| `comment` | Application comment for desktop entry | No | Empty |
| `category` | Desktop entry category | No | `Utility` |
| `icon` | Path to icon file | No | Auto-generated |
| `binary` | Binary name | No | Auto-detected from install_folder/bin |

## Outputs

| Output | Description |
|--------|-------------|
| `appimage` | Path to the generated AppImage file |

## Example Workflow

```yaml
name: Build and Release

# Will trigger when a commit is tagged 'v*' (v1.0.0 for example)
on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    name: Build, package, release
    runs-on: ubuntu-24.04
    steps:
      # Checkout your repo
      - uses: actions/checkout@v4

      # Install Qt
      - name: Install Qt
        uses: jurplel/install-qt-action@v4.2.1
        with:
          version: '6.8.3'

      # Build and install your project
      - name: Build project
        run: |
         cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$(readlink -f ./install)
         cmake --build build
         cmake --install build

      # Package into .AppImage
      - name: Create AppImage
        id: appimage
        uses: Kidev/qt-appimage@v1
        with:
          install_folder: './install'
          app_name: 'MyApplication'
          comment: 'An awesome Qt application'
          category: 'Graphics'
          icon: './icon.png'
          binary: 'myapp'

      # Extract version from the commit tag
      - name: Get Version
        id: get_version
        run: echo "VERSION=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT

      # Create release and upload AppImage
      - name: Create and Upload Release
        uses: softprops/action-gh-release@v2
        with:
          files: ${{ steps.appimage.outputs.appimage }}
          name: MyApplication ${{ steps.get_version.outputs.VERSION }}
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Requirements

The folder with your Qt app installed must contain:  
- `bin/` directory with the executable  
- `lib/` directory with Qt libraries  
- `plugins/` directory with Qt plugins  
- Optional: `qml/` directory with QML modules  
  
## Example usage

The easiest way to make the folder of `install_folder` compatible is to use the Qt features.  
Here is a typical CMakeLists.txt that works perfectly for Linux, and handles:  
- C++ sources (*.cpp *.h *.hpp *.hxx...)  
- QML files (*.qml) grouped in a module  
- Custom additional libraries  
- Custom additional headers  

To build, use:  
```console
kidev:~$ cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$(readlink -f ./install)
kidev:~$ cmake --build build
kidev:~$ cmake --install build
```

Using a CMakeLists.txt like this:  
```cmake
cmake_minimum_required(VERSION 3.22)

# Register all your sources
file(GLOB_RECURSE SOURCES_CPP RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.cpp)
file(GLOB_RECURSE SOURCES_HPP RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.h*)
file(GLOB_RECURSE SOURCES_QML RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.qml)
set(CUSTOM_LIB mylib)
set(CUSTOM_LIB_FOLDER /home/user/myextra/lib)
set(CUSTOM_INC_FOLDER /home/user/myextra/include)

# Define project
project(
    myproject
    VERSION "0.0.1"
    LANGUAGES CXX
)

# Register required Qt components
find_package(
    Qt6 
    REQUIRED COMPONENTS 
        Core
        Gui
        Quick
        Qml
)

# Register eventual extra libraries
find_library(
    EXTRALIB ${CUSTOM_LIB}
    PATHS ${CUSTOM_LIB_FOLDER}
    NO_DEFAULT_PATH REQUIRED
)

qt_standard_project_setup()

qt_add_executable(${PROJECT_NAME} ${SOURCES_CPP} ${SOURCES_HPP})

# Register your QML files as module
# Allows to use this in main.cpp to show your qml/Main.qml: 
# engine.loadFromModule("qml", "Main");
qt_add_qml_module(
    ${PROJECT_NAME}
    URI "qml"
    QML_FILES ${SOURCES_QML}
    RESOURCE_PREFIX "/qt/qml"
    OUTPUT_DIRECTORY "qml"
)

# Add ./src and eventual custom folder as includes
target_include_directories(
    ${PROJECT_NAME} 
    PRIVATE 
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CUSTOM_INC_FOLDER}
)

# Link Qt and your eventual extra libs
target_link_libraries(
    ${PROJECT_NAME}
    PUBLIC 
        Qt6::Core
        Qt6::Gui
        Qt6::Quick
        Qt6::Qml
        ${EXTRALIB}
)

# Install into folder
install(
    TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

qt_generate_deploy_qml_app_script(
    TARGET ${PROJECT_NAME}
    OUTPUT_SCRIPT deploy_script
    NO_UNSUPPORTED_PLATFORM_ERROR
    DEPLOY_USER_QML_MODULES_ON_UNSUPPORTED_PLATFORM
    NO_TRANSLATIONS
)

install(SCRIPT ${deploy_script})
```

Then you just have to use the action (given you have a `icon.png` available, you can remove the parameter if you want):  
```yaml
- name: Build AppImage
  uses: Kidev/qt-appimage@v1
  with:
    install_folder: './install'
    app_name: 'MyProject'
    comment: 'My Qt application'
    category: 'Graphics'
    icon: 'icon.png'
    binary: 'myproject'
```

The above workflow given as example [here](#example-workflow) works very well with this setup! It installs, build, packages, and uploads a Qt app

## Troubleshooting

1. **Binary not found**: Ensure your executable is in `install_folder/bin/` and is executable
2. **Missing libraries**: The action automatically copies all libraries from `install_folder/lib/`
3. **Plugin loading errors**: Set `QT_DEBUG_PLUGINS=1` to debug plugin issues

