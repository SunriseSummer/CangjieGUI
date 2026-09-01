#include <SDL3/SDL.h>

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#undef CreateWindow

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <numeric>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {

using Clock = std::chrono::steady_clock;

class ScopeExit {
public:
  explicit ScopeExit(std::function<void()> action)
      : action_(std::move(action)) {}
  ScopeExit(const ScopeExit &) = delete;
  ScopeExit &operator=(const ScopeExit &) = delete;
  ~ScopeExit() {
    if (action_) {
      action_();
    }
  }

private:
  std::function<void()> action_;
};

class SdlApi {
public:
  explicit SdlApi(const wchar_t *path) {
    module_ = LoadLibraryW(path);
    if (module_ == nullptr) {
      throw std::runtime_error("failed to load SDL3.dll");
    }

    Init = load<decltype(Init)>("SDL_Init");
    Quit = load<decltype(Quit)>("SDL_Quit");
    GetError = load<decltype(GetError)>("SDL_GetError");
    GetRevision = load<decltype(GetRevision)>("SDL_GetRevision");
    CreateWindow = load<decltype(CreateWindow)>("SDL_CreateWindow");
    DestroyWindow = load<decltype(DestroyWindow)>("SDL_DestroyWindow");
    GetWindowSizeInPixels =
        load<decltype(GetWindowSizeInPixels)>("SDL_GetWindowSizeInPixels");
    PumpEvents = load<decltype(PumpEvents)>("SDL_PumpEvents");

    CreateRenderer = load<decltype(CreateRenderer)>("SDL_CreateRenderer");
    DestroyRenderer = load<decltype(DestroyRenderer)>("SDL_DestroyRenderer");
    GetRendererName = load<decltype(GetRendererName)>("SDL_GetRendererName");
    SetRenderVSync = load<decltype(SetRenderVSync)>("SDL_SetRenderVSync");
    GetRenderOutputSize =
        load<decltype(GetRenderOutputSize)>("SDL_GetRenderOutputSize");
    CreateTexture = load<decltype(CreateTexture)>("SDL_CreateTexture");
    DestroyTexture = load<decltype(DestroyTexture)>("SDL_DestroyTexture");
    SetTextureScaleMode =
        load<decltype(SetTextureScaleMode)>("SDL_SetTextureScaleMode");
    SetTextureBlendMode =
        load<decltype(SetTextureBlendMode)>("SDL_SetTextureBlendMode");
    SetRenderTarget = load<decltype(SetRenderTarget)>("SDL_SetRenderTarget");
    SetRenderDrawColor =
        load<decltype(SetRenderDrawColor)>("SDL_SetRenderDrawColor");
    RenderClear = load<decltype(RenderClear)>("SDL_RenderClear");
    RenderTexture = load<decltype(RenderTexture)>("SDL_RenderTexture");
    RenderPresent = load<decltype(RenderPresent)>("SDL_RenderPresent");
    RenderReadPixels = load<decltype(RenderReadPixels)>("SDL_RenderReadPixels");
    DestroySurface = load<decltype(DestroySurface)>("SDL_DestroySurface");

    CreateGPUDevice = load<decltype(CreateGPUDevice)>("SDL_CreateGPUDevice");
    DestroyGPUDevice = load<decltype(DestroyGPUDevice)>("SDL_DestroyGPUDevice");
    GetGPUDeviceDriver =
        load<decltype(GetGPUDeviceDriver)>("SDL_GetGPUDeviceDriver");
    GetGPUDeviceProperties =
        load<decltype(GetGPUDeviceProperties)>("SDL_GetGPUDeviceProperties");
    GetStringProperty =
        load<decltype(GetStringProperty)>("SDL_GetStringProperty");
    ClaimWindowForGPUDevice =
        load<decltype(ClaimWindowForGPUDevice)>("SDL_ClaimWindowForGPUDevice");
    ReleaseWindowFromGPUDevice = load<decltype(ReleaseWindowFromGPUDevice)>(
        "SDL_ReleaseWindowFromGPUDevice");
    SetGPUSwapchainParameters = load<decltype(SetGPUSwapchainParameters)>(
        "SDL_SetGPUSwapchainParameters");
    GetGPUSwapchainTextureFormat = load<decltype(GetGPUSwapchainTextureFormat)>(
        "SDL_GetGPUSwapchainTextureFormat");
    GPUTextureSupportsSampleCount =
        load<decltype(GPUTextureSupportsSampleCount)>(
            "SDL_GPUTextureSupportsSampleCount");
    CreateGPUTexture = load<decltype(CreateGPUTexture)>("SDL_CreateGPUTexture");
    ReleaseGPUTexture =
        load<decltype(ReleaseGPUTexture)>("SDL_ReleaseGPUTexture");
    AcquireGPUCommandBuffer =
        load<decltype(AcquireGPUCommandBuffer)>("SDL_AcquireGPUCommandBuffer");
    CancelGPUCommandBuffer =
        load<decltype(CancelGPUCommandBuffer)>("SDL_CancelGPUCommandBuffer");
    WaitAndAcquireGPUSwapchainTexture =
        load<decltype(WaitAndAcquireGPUSwapchainTexture)>(
            "SDL_WaitAndAcquireGPUSwapchainTexture");
    BeginGPURenderPass =
        load<decltype(BeginGPURenderPass)>("SDL_BeginGPURenderPass");
    EndGPURenderPass = load<decltype(EndGPURenderPass)>("SDL_EndGPURenderPass");
    SubmitGPUCommandBuffer =
        load<decltype(SubmitGPUCommandBuffer)>("SDL_SubmitGPUCommandBuffer");
    WaitForGPUIdle = load<decltype(WaitForGPUIdle)>("SDL_WaitForGPUIdle");
  }

  SdlApi(const SdlApi &) = delete;
  SdlApi &operator=(const SdlApi &) = delete;

  ~SdlApi() {
    if (module_ != nullptr) {
      FreeLibrary(module_);
    }
  }

  decltype(&SDL_Init) Init{};
  decltype(&SDL_Quit) Quit{};
  decltype(&SDL_GetError) GetError{};
  decltype(&SDL_GetRevision) GetRevision{};
  decltype(&SDL_CreateWindow) CreateWindow{};
  decltype(&SDL_DestroyWindow) DestroyWindow{};
  decltype(&SDL_GetWindowSizeInPixels) GetWindowSizeInPixels{};
  decltype(&SDL_PumpEvents) PumpEvents{};

  decltype(&SDL_CreateRenderer) CreateRenderer{};
  decltype(&SDL_DestroyRenderer) DestroyRenderer{};
  decltype(&SDL_GetRendererName) GetRendererName{};
  decltype(&SDL_SetRenderVSync) SetRenderVSync{};
  decltype(&SDL_GetRenderOutputSize) GetRenderOutputSize{};
  decltype(&SDL_CreateTexture) CreateTexture{};
  decltype(&SDL_DestroyTexture) DestroyTexture{};
  decltype(&SDL_SetTextureScaleMode) SetTextureScaleMode{};
  decltype(&SDL_SetTextureBlendMode) SetTextureBlendMode{};
  decltype(&SDL_SetRenderTarget) SetRenderTarget{};
  decltype(&SDL_SetRenderDrawColor) SetRenderDrawColor{};
  decltype(&SDL_RenderClear) RenderClear{};
  decltype(&SDL_RenderTexture) RenderTexture{};
  decltype(&SDL_RenderPresent) RenderPresent{};
  decltype(&SDL_RenderReadPixels) RenderReadPixels{};
  decltype(&SDL_DestroySurface) DestroySurface{};

  decltype(&SDL_CreateGPUDevice) CreateGPUDevice{};
  decltype(&SDL_DestroyGPUDevice) DestroyGPUDevice{};
  decltype(&SDL_GetGPUDeviceDriver) GetGPUDeviceDriver{};
  decltype(&SDL_GetGPUDeviceProperties) GetGPUDeviceProperties{};
  decltype(&SDL_GetStringProperty) GetStringProperty{};
  decltype(&SDL_ClaimWindowForGPUDevice) ClaimWindowForGPUDevice{};
  decltype(&SDL_ReleaseWindowFromGPUDevice) ReleaseWindowFromGPUDevice{};
  decltype(&SDL_SetGPUSwapchainParameters) SetGPUSwapchainParameters{};
  decltype(&SDL_GetGPUSwapchainTextureFormat) GetGPUSwapchainTextureFormat{};
  decltype(&SDL_GPUTextureSupportsSampleCount) GPUTextureSupportsSampleCount{};
  decltype(&SDL_CreateGPUTexture) CreateGPUTexture{};
  decltype(&SDL_ReleaseGPUTexture) ReleaseGPUTexture{};
  decltype(&SDL_AcquireGPUCommandBuffer) AcquireGPUCommandBuffer{};
  decltype(&SDL_CancelGPUCommandBuffer) CancelGPUCommandBuffer{};
  decltype(&SDL_WaitAndAcquireGPUSwapchainTexture)
      WaitAndAcquireGPUSwapchainTexture{};
  decltype(&SDL_BeginGPURenderPass) BeginGPURenderPass{};
  decltype(&SDL_EndGPURenderPass) EndGPURenderPass{};
  decltype(&SDL_SubmitGPUCommandBuffer) SubmitGPUCommandBuffer{};
  decltype(&SDL_WaitForGPUIdle) WaitForGPUIdle{};

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

struct Options {
  int width = 3780;
  int height = 2430;
  int warmup = 30;
  int frames = 180;
  int repeats = 3;
  std::string output;
};

struct Distribution {
  double mean = 0.0;
  double p50 = 0.0;
  double p95 = 0.0;
  double maximum = 0.0;
};

struct BatchResult {
  int repeat = 0;
  std::string kind;
  std::string backend;
  std::string device;
  int output_width = 0;
  int output_height = 0;
  int warmup = 0;
  int frames = 0;
  Distribution submit_ms;
  double drain_ms = 0.0;
  double complete_mean_ms = 0.0;
};

[[noreturn]] void fail(const SdlApi &api, const std::string &operation) {
  const char *error = api.GetError();
  throw std::runtime_error(operation + ": " +
                           (error != nullptr ? error : "unknown SDL error"));
}

double elapsedMs(Clock::time_point start, Clock::time_point end) {
  return std::chrono::duration<double, std::milli>(end - start).count();
}

Distribution summarize(const std::vector<double> &samples) {
  if (samples.empty()) {
    throw std::runtime_error("cannot summarize an empty sample set");
  }
  std::vector<double> sorted = samples;
  std::sort(sorted.begin(), sorted.end());
  const auto percentile = [&sorted](double probability) {
    const double rank =
        std::ceil(probability * static_cast<double>(sorted.size()));
    const std::size_t index =
        static_cast<std::size_t>(std::max(1.0, rank) - 1.0);
    return sorted[std::min(index, sorted.size() - 1)];
  };
  const double sum = std::accumulate(samples.begin(), samples.end(), 0.0);
  return Distribution{sum / static_cast<double>(samples.size()),
                      percentile(0.50), percentile(0.95), sorted.back()};
}

SDL_Window *createProbeWindow(SdlApi &api, const Options &options,
                              const char *title) {
  SDL_Window *window = api.CreateWindow(title, options.width, options.height,
                                        SDL_WINDOW_HIGH_PIXEL_DENSITY);
  if (window == nullptr) {
    fail(api, "SDL_CreateWindow");
  }
  api.PumpEvents();
  return window;
}

void recordRendererFrame(SdlApi &api, SDL_Renderer *renderer,
                         SDL_Texture *target, int frame) {
  if (!api.SetRenderTarget(renderer, target)) {
    fail(api, "SDL_SetRenderTarget(target)");
  }
  const Uint8 red = static_cast<Uint8>(32 + (frame % 160));
  const Uint8 green = static_cast<Uint8>(48 + ((frame * 3) % 144));
  const Uint8 blue = static_cast<Uint8>(64 + ((frame * 7) % 128));
  if (!api.SetRenderDrawColor(renderer, red, green, blue, 255) ||
      !api.RenderClear(renderer)) {
    fail(api, "SDL_RenderClear(SSAA target)");
  }
  if (!api.SetRenderTarget(renderer, nullptr)) {
    fail(api, "SDL_SetRenderTarget(swapchain)");
  }
  if (!api.RenderTexture(renderer, target, nullptr, nullptr)) {
    fail(api, "SDL_RenderTexture(SSAA resolve)");
  }
  if (!api.RenderPresent(renderer)) {
    fail(api, "SDL_RenderPresent");
  }
}

BatchResult runRendererSsaa(SdlApi &api, const Options &options) {
  SDL_Window *window =
      createProbeWindow(api, options, "CUI native probe: SDL_Renderer 2x SSAA");
  ScopeExit window_guard([&api, window] { api.DestroyWindow(window); });

  SDL_Renderer *renderer = api.CreateRenderer(window, "direct3d11");
  if (renderer == nullptr) {
    fail(api, "SDL_CreateRenderer(direct3d11)");
  }
  ScopeExit renderer_guard([&api, renderer] { api.DestroyRenderer(renderer); });
  if (!api.SetRenderVSync(renderer, 0)) {
    fail(api, "SDL_SetRenderVSync(0)");
  }

  int output_width = 0;
  int output_height = 0;
  if (!api.GetRenderOutputSize(renderer, &output_width, &output_height)) {
    fail(api, "SDL_GetRenderOutputSize");
  }
  if (output_width <= 0 || output_height <= 0 || output_width > 8192 ||
      output_height > 8192) {
    throw std::runtime_error("unexpected renderer output dimensions");
  }

  SDL_Texture *target = api.CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
                                          SDL_TEXTUREACCESS_TARGET,
                                          output_width * 2, output_height * 2);
  if (target == nullptr) {
    fail(api, "SDL_CreateTexture(2x SSAA)");
  }
  ScopeExit texture_guard([&api, target] { api.DestroyTexture(target); });
  if (!api.SetTextureScaleMode(target, SDL_SCALEMODE_LINEAR) ||
      !api.SetTextureBlendMode(target, SDL_BLENDMODE_NONE)) {
    fail(api, "configure SSAA texture");
  }

  for (int frame = 0; frame < options.warmup; ++frame) {
    recordRendererFrame(api, renderer, target, frame);
  }

  std::vector<double> samples;
  samples.reserve(static_cast<std::size_t>(options.frames));
  const Clock::time_point batch_start = Clock::now();
  for (int frame = 0; frame < options.frames; ++frame) {
    const Clock::time_point start = Clock::now();
    recordRendererFrame(api, renderer, target, frame + options.warmup);
    samples.push_back(elapsedMs(start, Clock::now()));
  }
  const Clock::time_point submit_end = Clock::now();

  const SDL_Rect pixel{0, 0, 1, 1};
  SDL_Surface *readback = api.RenderReadPixels(renderer, &pixel);
  if (readback == nullptr) {
    fail(api, "SDL_RenderReadPixels(drain)");
  }
  api.DestroySurface(readback);
  const Clock::time_point drain_end = Clock::now();

  const char *name = api.GetRendererName(renderer);
  return BatchResult{0,
                     "renderer_ssaa2",
                     name != nullptr ? name : "direct3d11",
                     "",
                     output_width,
                     output_height,
                     options.warmup,
                     options.frames,
                     summarize(samples),
                     elapsedMs(submit_end, drain_end),
                     elapsedMs(batch_start, drain_end) /
                         static_cast<double>(options.frames)};
}

struct GpuFrameContext {
  SDL_GPUDevice *device{};
  SDL_Window *window{};
  SDL_GPUTexture *multisample{};
  int expected_width = 0;
  int expected_height = 0;
};

void recordGpuFrame(SdlApi &api, const GpuFrameContext &context, int frame) {
  SDL_GPUCommandBuffer *command_buffer =
      api.AcquireGPUCommandBuffer(context.device);
  if (command_buffer == nullptr) {
    fail(api, "SDL_AcquireGPUCommandBuffer");
  }

  SDL_GPUTexture *swapchain = nullptr;
  Uint32 width = 0;
  Uint32 height = 0;
  if (!api.WaitAndAcquireGPUSwapchainTexture(command_buffer, context.window,
                                             &swapchain, &width, &height)) {
    api.CancelGPUCommandBuffer(command_buffer);
    fail(api, "SDL_WaitAndAcquireGPUSwapchainTexture");
  }
  if (swapchain == nullptr) {
    api.CancelGPUCommandBuffer(command_buffer);
    throw std::runtime_error("swapchain texture unavailable");
  }
  if (width != static_cast<Uint32>(context.expected_width) ||
      height != static_cast<Uint32>(context.expected_height)) {
    api.CancelGPUCommandBuffer(command_buffer);
    throw std::runtime_error("swapchain dimensions changed during the probe");
  }

  SDL_GPUColorTargetInfo target{};
  target.texture = context.multisample;
  target.clear_color =
      SDL_FColor{static_cast<float>(32 + (frame % 160)) / 255.0F,
                 static_cast<float>(48 + ((frame * 3) % 144)) / 255.0F,
                 static_cast<float>(64 + ((frame * 7) % 128)) / 255.0F, 1.0F};
  target.load_op = SDL_GPU_LOADOP_CLEAR;
  target.store_op = SDL_GPU_STOREOP_RESOLVE;
  target.resolve_texture = swapchain;
  target.cycle = true;

  SDL_GPURenderPass *pass =
      api.BeginGPURenderPass(command_buffer, &target, 1, nullptr);
  if (pass == nullptr) {
    api.CancelGPUCommandBuffer(command_buffer);
    fail(api, "SDL_BeginGPURenderPass(4x MSAA)");
  }
  api.EndGPURenderPass(pass);
  if (!api.SubmitGPUCommandBuffer(command_buffer)) {
    fail(api, "SDL_SubmitGPUCommandBuffer");
  }
}

BatchResult runGpuMsaa(SdlApi &api, const Options &options) {
  SDL_Window *window =
      createProbeWindow(api, options, "CUI native probe: SDL_GPU 4x MSAA");
  ScopeExit window_guard([&api, window] { api.DestroyWindow(window); });

  SDL_GPUDevice *device =
      api.CreateGPUDevice(SDL_GPU_SHADERFORMAT_DXIL, false, "direct3d12");
  if (device == nullptr) {
    fail(api, "SDL_CreateGPUDevice(direct3d12)");
  }
  ScopeExit device_guard([&api, device] { api.DestroyGPUDevice(device); });
  if (!api.ClaimWindowForGPUDevice(device, window)) {
    fail(api, "SDL_ClaimWindowForGPUDevice");
  }
  ScopeExit claim_guard([&api, device, window] {
    api.ReleaseWindowFromGPUDevice(device, window);
  });
  if (!api.SetGPUSwapchainParameters(device, window,
                                     SDL_GPU_SWAPCHAINCOMPOSITION_SDR,
                                     SDL_GPU_PRESENTMODE_IMMEDIATE)) {
    fail(api, "SDL_SetGPUSwapchainParameters(IMMEDIATE)");
  }

  int output_width = 0;
  int output_height = 0;
  if (!api.GetWindowSizeInPixels(window, &output_width, &output_height)) {
    fail(api, "SDL_GetWindowSizeInPixels");
  }
  if (output_width <= 0 || output_height <= 0 || output_width > 8192 ||
      output_height > 8192) {
    throw std::runtime_error("unexpected GPU output dimensions");
  }

  const SDL_GPUTextureFormat format =
      api.GetGPUSwapchainTextureFormat(device, window);
  if (format == SDL_GPU_TEXTUREFORMAT_INVALID) {
    fail(api, "SDL_GetGPUSwapchainTextureFormat");
  }
  if (!api.GPUTextureSupportsSampleCount(device, format,
                                         SDL_GPU_SAMPLECOUNT_4)) {
    throw std::runtime_error(
        "swapchain format does not support 4x MSAA color targets");
  }

  SDL_GPUTextureCreateInfo create_info{};
  create_info.type = SDL_GPU_TEXTURETYPE_2D;
  create_info.format = format;
  create_info.usage = SDL_GPU_TEXTUREUSAGE_COLOR_TARGET;
  create_info.width = static_cast<Uint32>(output_width);
  create_info.height = static_cast<Uint32>(output_height);
  create_info.layer_count_or_depth = 1;
  create_info.num_levels = 1;
  create_info.sample_count = SDL_GPU_SAMPLECOUNT_4;
  SDL_GPUTexture *multisample = api.CreateGPUTexture(device, &create_info);
  if (multisample == nullptr) {
    fail(api, "SDL_CreateGPUTexture(4x MSAA)");
  }
  ScopeExit texture_guard([&api, device, multisample] {
    api.ReleaseGPUTexture(device, multisample);
  });

  const GpuFrameContext context{device, window, multisample, output_width,
                                output_height};
  for (int frame = 0; frame < options.warmup; ++frame) {
    recordGpuFrame(api, context, frame);
  }
  if (!api.WaitForGPUIdle(device)) {
    fail(api, "SDL_WaitForGPUIdle(warmup)");
  }

  std::vector<double> samples;
  samples.reserve(static_cast<std::size_t>(options.frames));
  const Clock::time_point batch_start = Clock::now();
  for (int frame = 0; frame < options.frames; ++frame) {
    const Clock::time_point start = Clock::now();
    recordGpuFrame(api, context, frame + options.warmup);
    samples.push_back(elapsedMs(start, Clock::now()));
  }
  const Clock::time_point submit_end = Clock::now();
  if (!api.WaitForGPUIdle(device)) {
    fail(api, "SDL_WaitForGPUIdle(measured)");
  }
  const Clock::time_point drain_end = Clock::now();

  const char *driver = api.GetGPUDeviceDriver(device);
  const SDL_PropertiesID properties = api.GetGPUDeviceProperties(device);
  const char *device_name =
      properties != 0 ? api.GetStringProperty(
                            properties, SDL_PROP_GPU_DEVICE_NAME_STRING, "")
                      : "";
  return BatchResult{0,
                     "gpu_msaa4",
                     driver != nullptr ? driver : "direct3d12",
                     device_name != nullptr ? device_name : "",
                     output_width,
                     output_height,
                     options.warmup,
                     options.frames,
                     summarize(samples),
                     elapsedMs(submit_end, drain_end),
                     elapsedMs(batch_start, drain_end) /
                         static_cast<double>(options.frames)};
}

std::string jsonEscape(const std::string &value) {
  std::ostringstream output;
  for (const unsigned char character : value) {
    switch (character) {
    case '\\':
      output << "\\\\";
      break;
    case '"':
      output << "\\\"";
      break;
    case '\n':
      output << "\\n";
      break;
    case '\r':
      output << "\\r";
      break;
    case '\t':
      output << "\\t";
      break;
    default:
      if (character < 0x20) {
        output << "\\u" << std::hex << std::setw(4) << std::setfill('0')
               << static_cast<int>(character) << std::dec << std::setfill(' ');
      } else {
        output << character;
      }
    }
  }
  return output.str();
}

double median(std::vector<double> values) {
  std::sort(values.begin(), values.end());
  const std::size_t middle = values.size() / 2;
  if ((values.size() % 2) == 0) {
    return (values[middle - 1] + values[middle]) / 2.0;
  }
  return values[middle];
}

std::string renderJson(const std::vector<BatchResult> &batches,
                       const SdlApi &api) {
  std::vector<double> ssaa_complete;
  std::vector<double> msaa_complete;
  std::vector<double> ssaa_p95;
  std::vector<double> msaa_p95;
  for (const BatchResult &batch : batches) {
    if (batch.kind == "renderer_ssaa2") {
      ssaa_complete.push_back(batch.complete_mean_ms);
      ssaa_p95.push_back(batch.submit_ms.p95);
    } else {
      msaa_complete.push_back(batch.complete_mean_ms);
      msaa_p95.push_back(batch.submit_ms.p95);
    }
  }
  const double ssaa_median = median(ssaa_complete);
  const double msaa_median = median(msaa_complete);
  const double speedup = ssaa_median / msaa_median;
  const double ssaa_p95_median = median(ssaa_p95);
  const double msaa_p95_median = median(msaa_p95);
  const bool candidate = speedup >= 1.25 && msaa_p95_median <= ssaa_p95_median;

  std::ostringstream output;
  output << std::fixed << std::setprecision(6);
  output << "{\n";
  output << "  \"schema\": \"cui.sdl-gpu-msaa-probe.v1\",\n";
  output << "  \"sdl_revision\": \"" << jsonEscape(api.GetRevision())
         << "\",\n";
  output << "  \"method\": \"alternating ABBA/BAAB, clear-only target/resolve "
            "pressure floor, IMMEDIATE present, final GPU drain\",\n";
  output << "  \"batches\": [\n";
  for (std::size_t index = 0; index < batches.size(); ++index) {
    const BatchResult &batch = batches[index];
    output << "    {\"order\": " << (index + 1)
           << ", \"repeat\": " << batch.repeat << ", \"kind\": \"" << batch.kind
           << "\", \"backend\": \"" << jsonEscape(batch.backend)
           << "\", \"device\": \"" << jsonEscape(batch.device)
           << "\", \"output_width\": " << batch.output_width
           << ", \"output_height\": " << batch.output_height
           << ", \"warmup\": " << batch.warmup
           << ", \"frames\": " << batch.frames
           << ", \"submit_ms\": {\"mean\": " << batch.submit_ms.mean
           << ", \"p50\": " << batch.submit_ms.p50
           << ", \"p95\": " << batch.submit_ms.p95
           << ", \"max\": " << batch.submit_ms.maximum
           << "}, \"drain_ms\": " << batch.drain_ms
           << ", \"complete_mean_ms\": " << batch.complete_mean_ms << "}";
    output << (index + 1 == batches.size() ? "\n" : ",\n");
  }
  output << "  ],\n";
  output << "  \"aggregate\": {\n";
  output << "    \"renderer_ssaa2_complete_mean_median_ms\": " << ssaa_median
         << ",\n";
  output << "    \"gpu_msaa4_complete_mean_median_ms\": " << msaa_median
         << ",\n";
  output << "    \"renderer_over_gpu_speedup\": " << speedup << ",\n";
  output << "    \"renderer_ssaa2_submit_p95_median_ms\": " << ssaa_p95_median
         << ",\n";
  output << "    \"gpu_msaa4_submit_p95_median_ms\": " << msaa_p95_median
         << ",\n";
  output << "    \"passes_1_25x_feasibility_gate\": "
         << (candidate ? "true" : "false") << "\n";
  output << "  },\n";
  output << "  \"interpretation_limit\": \"No scene shaders or geometry: "
            "passing promotes a representative scene prototype, not the "
            "production backend.\"\n";
  output << "}\n";
  return output.str();
}

Options parseOptions(int argc, char **argv) {
  Options options;
  for (int index = 1; index < argc; ++index) {
    const std::string argument = argv[index];
    const auto readInt = [&index, argc, argv, &argument]() {
      if (++index >= argc) {
        throw std::runtime_error("missing value for " + argument);
      }
      return std::stoi(argv[index]);
    };
    if (argument == "--width") {
      options.width = readInt();
    } else if (argument == "--height") {
      options.height = readInt();
    } else if (argument == "--warmup") {
      options.warmup = readInt();
    } else if (argument == "--frames") {
      options.frames = readInt();
    } else if (argument == "--repeats") {
      options.repeats = readInt();
    } else if (argument == "--output") {
      if (++index >= argc) {
        throw std::runtime_error("missing value for --output");
      }
      options.output = argv[index];
    } else {
      throw std::runtime_error("unknown argument: " + argument);
    }
  }
  if (options.width <= 0 || options.height <= 0 || options.warmup < 0 ||
      options.frames < 10 || options.repeats < 1) {
    throw std::runtime_error("width/height/repeats must be positive, warmup "
                             "non-negative, and frames at least 10");
  }
  return options;
}

} // namespace

int main(int argc, char **argv) {
  try {
    const Options options = parseOptions(argc, argv);
    SdlApi api(L"SDL3.dll");
    if (!api.Init(SDL_INIT_VIDEO)) {
      fail(api, "SDL_Init(SDL_INIT_VIDEO)");
    }
    ScopeExit sdl_guard([&api] { api.Quit(); });

    std::vector<BatchResult> batches;
    batches.reserve(static_cast<std::size_t>(options.repeats) * 4);
    for (int repeat = 1; repeat <= options.repeats; ++repeat) {
      const bool abba = (repeat % 2) == 1;
      for (int slot = 0; slot < 4; ++slot) {
        const bool renderer =
            abba ? (slot == 0 || slot == 3) : (slot == 1 || slot == 2);
        BatchResult batch =
            renderer ? runRendererSsaa(api, options) : runGpuMsaa(api, options);
        batch.repeat = repeat;
        batches.push_back(std::move(batch));
      }
    }

    const std::string report = renderJson(batches, api);
    std::cout << report;
    if (!options.output.empty()) {
      std::ofstream file(options.output, std::ios::binary);
      if (!file) {
        throw std::runtime_error("failed to open output file: " +
                                 options.output);
      }
      file << report;
      if (!file) {
        throw std::runtime_error("failed to write output file: " +
                                 options.output);
      }
    }
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "sdl_gpu_msaa_probe: " << error.what() << '\n';
    return 1;
  }
}
