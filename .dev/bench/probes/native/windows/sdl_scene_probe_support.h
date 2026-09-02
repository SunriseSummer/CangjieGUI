#pragma once

#include <SDL3/SDL.h>

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#undef CreateWindow

#include <cstring>
#include <functional>
#include <stdexcept>
#include <string>
#include <utility>

#define CUI_SCENE_SDL_SYMBOLS(X)                                               \
  X(Init)                                                                      \
  X(Quit)                                                                      \
  X(GetError)                                                                  \
  X(GetRevision)                                                               \
  X(CreateWindow)                                                              \
  X(DestroyWindow)                                                             \
  X(GetWindowSizeInPixels)                                                     \
  X(PumpEvents)                                                                \
  X(CreateRenderer)                                                            \
  X(DestroyRenderer)                                                           \
  X(GetRendererName)                                                           \
  X(SetRenderVSync)                                                            \
  X(SetRenderDrawBlendMode)                                                    \
  X(GetRenderOutputSize)                                                       \
  X(SetRenderScale)                                                            \
  X(SetRenderClipRect)                                                         \
  X(CreateTexture)                                                             \
  X(DestroyTexture)                                                            \
  X(UpdateTexture)                                                             \
  X(SetTextureScaleMode)                                                       \
  X(SetTextureBlendMode)                                                       \
  X(SetRenderTarget)                                                           \
  X(SetRenderDrawColor)                                                        \
  X(RenderClear)                                                               \
  X(RenderGeometryRaw)                                                         \
  X(RenderTexture)                                                             \
  X(RenderPresent)                                                             \
  X(RenderReadPixels)                                                          \
  X(ConvertSurface)                                                            \
  X(DestroySurface)                                                            \
  X(CreateGPUDevice)                                                           \
  X(DestroyGPUDevice)                                                          \
  X(GetGPUDeviceDriver)                                                        \
  X(GetGPUDeviceProperties)                                                    \
  X(GetStringProperty)                                                         \
  X(ClaimWindowForGPUDevice)                                                   \
  X(ReleaseWindowFromGPUDevice)                                                \
  X(SetGPUSwapchainParameters)                                                 \
  X(GetGPUSwapchainTextureFormat)                                              \
  X(GPUTextureSupportsSampleCount)                                             \
  X(CreateGPUTexture)                                                          \
  X(ReleaseGPUTexture)                                                         \
  X(CreateGPUShader)                                                           \
  X(ReleaseGPUShader)                                                          \
  X(CreateGPUGraphicsPipeline)                                                 \
  X(ReleaseGPUGraphicsPipeline)                                                \
  X(CreateGPUBuffer)                                                           \
  X(ReleaseGPUBuffer)                                                          \
  X(CreateGPUTransferBuffer)                                                   \
  X(ReleaseGPUTransferBuffer)                                                  \
  X(MapGPUTransferBuffer)                                                      \
  X(UnmapGPUTransferBuffer)                                                    \
  X(CreateGPUSampler)                                                          \
  X(ReleaseGPUSampler)                                                         \
  X(AcquireGPUCommandBuffer)                                                   \
  X(CancelGPUCommandBuffer)                                                    \
  X(WaitAndAcquireGPUSwapchainTexture)                                         \
  X(BeginGPUCopyPass)                                                          \
  X(UploadToGPUBuffer)                                                         \
  X(UploadToGPUTexture)                                                        \
  X(DownloadFromGPUTexture)                                                    \
  X(EndGPUCopyPass)                                                            \
  X(BeginGPURenderPass)                                                        \
  X(EndGPURenderPass)                                                          \
  X(BindGPUGraphicsPipeline)                                                   \
  X(BindGPUVertexBuffers)                                                      \
  X(BindGPUFragmentSamplers)                                                   \
  X(PushGPUVertexUniformData)                                                  \
  X(PushGPUFragmentUniformData)                                                \
  X(SetGPUViewport)                                                            \
  X(SetGPUScissor)                                                             \
  X(DrawGPUPrimitives)                                                         \
  X(SubmitGPUCommandBuffer)                                                    \
  X(SubmitGPUCommandBufferAndAcquireFence)                                     \
  X(WaitForGPUFences)                                                          \
  X(ReleaseGPUFence)                                                           \
  X(WaitForGPUIdle)

class SceneScopeExit {
public:
  explicit SceneScopeExit(std::function<void()> action)
      : action_(std::move(action)) {}
  SceneScopeExit(const SceneScopeExit &) = delete;
  SceneScopeExit &operator=(const SceneScopeExit &) = delete;
  ~SceneScopeExit() {
    if (action_) {
      action_();
    }
  }

private:
  std::function<void()> action_;
};

class SceneSdlApi {
public:
  explicit SceneSdlApi(const wchar_t *path) {
    module_ = LoadLibraryW(path);
    if (module_ == nullptr) {
      throw std::runtime_error("failed to load SDL3.dll");
    }
    try {
#define CUI_BIND_SCENE_SYMBOL(name) name = load<decltype(name)>("SDL_" #name);
      CUI_SCENE_SDL_SYMBOLS(CUI_BIND_SCENE_SYMBOL)
#undef CUI_BIND_SCENE_SYMBOL
    } catch (...) {
      FreeLibrary(module_);
      module_ = nullptr;
      throw;
    }
  }

  SceneSdlApi(const SceneSdlApi &) = delete;
  SceneSdlApi &operator=(const SceneSdlApi &) = delete;

  ~SceneSdlApi() {
    if (module_ != nullptr) {
      FreeLibrary(module_);
    }
  }

#define CUI_DECLARE_SCENE_SYMBOL(name) decltype(&SDL_##name) name{};
  CUI_SCENE_SDL_SYMBOLS(CUI_DECLARE_SCENE_SYMBOL)
#undef CUI_DECLARE_SCENE_SYMBOL

private:
  template <typename T> T load(const char *name) {
    FARPROC address = GetProcAddress(module_, name);
    if (address == nullptr) {
      throw std::runtime_error(std::string("missing SDL symbol: ") + name);
    }
    static_assert(sizeof(T) == sizeof(address));
    T typed{};
    std::memcpy(&typed, &address, sizeof(typed));
    return typed;
  }

  HMODULE module_{};
};

#undef CUI_SCENE_SDL_SYMBOLS
