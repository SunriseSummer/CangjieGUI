#include "sdl_scene_probe_support.h"

#include "color.frag.dxil.h"
#include "texture_rgba.frag.dxil.h"
#include "tri_color.vert.dxil.h"
#include "tri_texture.vert.dxil.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <fstream>
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

constexpr int kAtlasWidth = 64;
constexpr int kAtlasHeight = 64;

struct Options {
  int width = 3780;
  int height = 2430;
  int warmup = 30;
  int frames = 180;
  int repeats = 3;
  std::string output;
  std::string dump_prefix;
};

struct Color {
  float r;
  float g;
  float b;
  float a;
};

struct Vertex {
  float x;
  float y;
  float r;
  float g;
  float b;
  float a;
  float u;
  float v;
};

static_assert(sizeof(Vertex) == sizeof(float) * 8);
static_assert(offsetof(Vertex, r) == sizeof(float) * 2);
static_assert(offsetof(Vertex, u) == sizeof(float) * 6);

enum class Material { Solid, Atlas };

struct Packet {
  Material material;
  SDL_Rect clip;
  Uint32 first_vertex;
  Uint32 vertex_count;
};

struct Scene {
  int width;
  int height;
  std::vector<Vertex> vertices;
  std::vector<Packet> packets;
  std::vector<Uint8> atlas;
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
  int frame_packets = 0;
  int frame_vertices = 0;
  int warmup = 0;
  int frames = 0;
  Distribution submit_ms;
  double drain_ms = 0.0;
  double complete_mean_ms = 0.0;
};

struct PixelValidation {
  double mean_absolute_error = 0.0;
  int max_channel_error = 0;
  double pixels_over_16_ratio = 0.0;
  double renderer_content_ratio = 0.0;
  double gpu_content_ratio = 0.0;
  bool passed = false;
};

[[noreturn]] void fail(const SceneSdlApi &api, const std::string &operation) {
  const char *error = api.GetError();
  throw std::runtime_error(operation + ": " +
                           (error != nullptr ? error : "unknown SDL error"));
}

[[noreturn]] void failAfterSwapchainAcquire(SceneSdlApi &api,
                                            SDL_GPUCommandBuffer *command,
                                            const std::string &operation) {
  const char *raw_error = api.GetError();
  const std::string error =
      raw_error != nullptr ? raw_error : "unknown SDL error";
  const bool submitted = api.SubmitGPUCommandBuffer(command);
  throw std::runtime_error(
      operation + ": " + error +
      (submitted ? "" : " (command cleanup submit failed)"));
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
    const double rank = std::ceil(probability * sorted.size());
    const std::size_t index =
        static_cast<std::size_t>(std::max(1.0, rank) - 1.0);
    return sorted[std::min(index, sorted.size() - 1)];
  };
  return Distribution{std::accumulate(samples.begin(), samples.end(), 0.0) /
                          static_cast<double>(samples.size()),
                      percentile(0.50), percentile(0.95), sorted.back()};
}

double median(std::vector<double> values) {
  std::sort(values.begin(), values.end());
  const std::size_t middle = values.size() / 2;
  if ((values.size() % 2) == 0) {
    return (values[middle - 1] + values[middle]) / 2.0;
  }
  return values[middle];
}

SDL_Window *createProbeWindow(SceneSdlApi &api, const Options &options,
                              const char *title) {
  SDL_Window *window = api.CreateWindow(title, options.width, options.height,
                                        SDL_WINDOW_HIGH_PIXEL_DENSITY);
  if (window == nullptr) {
    fail(api, "SDL_CreateWindow");
  }
  api.PumpEvents();
  return window;
}

Vertex vertex(float x, float y, Color color, float u = 0.0F, float v = 0.0F) {
  return Vertex{x, y, color.r, color.g, color.b, color.a, u, v};
}

void addRect(std::vector<Vertex> &vertices, float x, float y, float w, float h,
             Color color) {
  const Vertex top_left = vertex(x, y, color);
  const Vertex top_right = vertex(x + w, y, color);
  const Vertex bottom_left = vertex(x, y + h, color);
  const Vertex bottom_right = vertex(x + w, y + h, color);
  vertices.insert(vertices.end(), {top_left, top_right, bottom_left, top_right,
                                   bottom_right, bottom_left});
}

void addTexturedRect(std::vector<Vertex> &vertices, float x, float y, float w,
                     float h, float u0, float v0, float u1, float v1,
                     Color color) {
  const Vertex top_left = vertex(x, y, color, u0, v0);
  const Vertex top_right = vertex(x + w, y, color, u1, v0);
  const Vertex bottom_left = vertex(x, y + h, color, u0, v1);
  const Vertex bottom_right = vertex(x + w, y + h, color, u1, v1);
  vertices.insert(vertices.end(), {top_left, top_right, bottom_left, top_right,
                                   bottom_right, bottom_left});
}

void addCircle(std::vector<Vertex> &vertices, float center_x, float center_y,
               float radius, Color color) {
  constexpr int kSegments = 32;
  constexpr float kPi = 3.14159265358979323846F;
  for (int segment = 0; segment < kSegments; ++segment) {
    const float first = 2.0F * kPi * static_cast<float>(segment) /
                        static_cast<float>(kSegments);
    const float second = 2.0F * kPi * static_cast<float>(segment + 1) /
                         static_cast<float>(kSegments);
    vertices.push_back(vertex(center_x, center_y, color));
    vertices.push_back(vertex(center_x + std::cos(first) * radius,
                              center_y + std::sin(first) * radius, color));
    vertices.push_back(vertex(center_x + std::cos(second) * radius,
                              center_y + std::sin(second) * radius, color));
  }
}

void finishPacket(Scene &scene, Material material, SDL_Rect clip,
                  std::size_t first) {
  const std::size_t count = scene.vertices.size() - first;
  if (count == 0 || count > UINT32_MAX || first > UINT32_MAX) {
    throw std::runtime_error("invalid representative-scene packet size");
  }
  scene.packets.push_back(Packet{material, clip, static_cast<Uint32>(first),
                                 static_cast<Uint32>(count)});
}

std::vector<Uint8> makeAtlas() {
  std::vector<Uint8> pixels(static_cast<std::size_t>(kAtlasWidth) *
                            kAtlasHeight * 4);
  for (int y = 0; y < kAtlasHeight; ++y) {
    for (int x = 0; x < kAtlasWidth; ++x) {
      const int local_x = x % 8;
      const int local_y = y % 8;
      const bool stem = local_x == 2 || local_y == 2 ||
                        (local_x == local_y && local_x >= 2 && local_x <= 6);
      const bool fringe = local_x == 1 || local_y == 1;
      const Uint8 alpha = stem ? 255 : (fringe ? 80 : 0);
      const std::size_t offset =
          (static_cast<std::size_t>(y) * kAtlasWidth + x) * 4;
      pixels[offset] = 255;
      pixels[offset + 1] = 255;
      pixels[offset + 2] = 255;
      pixels[offset + 3] = alpha;
    }
  }
  return pixels;
}

Scene makeScene(int width, int height) {
  Scene scene{width, height, {}, {}, makeAtlas()};
  scene.vertices.reserve(12000);
  scene.packets.reserve(96);

  const float sx = static_cast<float>(width) / 1260.0F;
  const float sy = static_cast<float>(height) / 810.0F;
  const SDL_Rect full_clip{0, 0, width, height};
  const Color navy{0.055F, 0.075F, 0.12F, 1.0F};
  const Color surface{0.105F, 0.13F, 0.19F, 1.0F};
  const Color card{0.14F, 0.17F, 0.235F, 1.0F};
  const Color muted{0.29F, 0.34F, 0.43F, 1.0F};
  const Color accent{0.22F, 0.62F, 0.93F, 1.0F};
  const Color success{0.24F, 0.79F, 0.56F, 1.0F};
  const Color text{0.88F, 0.92F, 0.98F, 0.92F};

  std::size_t first = scene.vertices.size();
  addRect(scene.vertices, 0.0F, 0.0F, static_cast<float>(width), 72.0F * sy,
          surface);
  addRect(scene.vertices, 0.0F, 72.0F * sy, 230.0F * sx,
          static_cast<float>(height) - 72.0F * sy, navy);
  addCircle(scene.vertices, 36.0F * sx, 36.0F * sy, 16.0F * std::min(sx, sy),
            accent);
  for (int item = 0; item < 10; ++item) {
    const float y = (105.0F + static_cast<float>(item) * 55.0F) * sy;
    addRect(scene.vertices, 22.0F * sx, y, 178.0F * sx, 34.0F * sy,
            item == 3 ? Color{accent.r, accent.g, accent.b, 0.30F} : muted);
  }
  finishPacket(scene, Material::Solid, full_clip, first);

  constexpr int kColumns = 3;
  constexpr int kRows = 12;
  const float content_x = 260.0F * sx;
  const float content_y = 96.0F * sy;
  const float gap_x = 18.0F * sx;
  const float gap_y = 14.0F * sy;
  const float content_width =
      static_cast<float>(width) - content_x - 30.0F * sx;
  const float content_height =
      static_cast<float>(height) - content_y - 24.0F * sy;
  const float card_width =
      (content_width - gap_x * static_cast<float>(kColumns - 1)) / kColumns;
  const float card_height =
      (content_height - gap_y * static_cast<float>(kRows - 1)) / kRows;

  for (int row = 0; row < kRows; ++row) {
    for (int column = 0; column < kColumns; ++column) {
      const int index = row * kColumns + column;
      const float x =
          content_x + static_cast<float>(column) * (card_width + gap_x);
      const float y =
          content_y + static_cast<float>(row) * (card_height + gap_y);
      const SDL_Rect clip{static_cast<int>(x), static_cast<int>(y),
                          std::max(1, static_cast<int>(card_width)),
                          std::max(1, static_cast<int>(card_height))};

      first = scene.vertices.size();
      addRect(scene.vertices, x, y, card_width, card_height, card);
      addRect(scene.vertices, x + 14.0F * sx, y + 13.0F * sy,
              card_width * 0.52F, 8.0F * sy, text);
      addCircle(scene.vertices, x + card_width - 28.0F * sx, y + 25.0F * sy,
                10.5F * std::min(sx, sy), (index % 3) == 0 ? accent : success);
      for (int bar = 0; bar < 4; ++bar) {
        const float bar_y = y + (39.0F + static_cast<float>(bar) * 16.0F) * sy;
        const float available = card_width - 28.0F * sx;
        addRect(scene.vertices, x + 14.0F * sx, bar_y, available, 6.0F * sy,
                Color{muted.r, muted.g, muted.b, 0.55F});
        const float fraction =
            0.24F + 0.12F * static_cast<float>((index + bar) % 5);
        addRect(scene.vertices, x + 14.0F * sx, bar_y, available * fraction,
                6.0F * sy, (bar % 2) == 0 ? accent : success);
      }
      addRect(scene.vertices, x + card_width * 0.58F, y + card_height * 0.50F,
              card_width * 0.38F, card_height * 0.38F,
              Color{accent.r, accent.g, accent.b, 0.16F});
      finishPacket(scene, Material::Solid, clip, first);

      first = scene.vertices.size();
      const float glyph_size = std::max(4.0F, 8.0F * std::min(sx, sy));
      for (int glyph = 0; glyph < 8; ++glyph) {
        const int cell = (index + glyph) % 64;
        const float u0 = static_cast<float>((cell % 8) * 8) / kAtlasWidth;
        const float v0 = static_cast<float>((cell / 8) * 8) / kAtlasHeight;
        const float u1 = u0 + 8.0F / kAtlasWidth;
        const float v1 = v0 + 8.0F / kAtlasHeight;
        addTexturedRect(scene.vertices, x + (14.0F + glyph * 10.0F) * sx,
                        y + card_height - 22.0F * sy, glyph_size, glyph_size,
                        u0, v0, u1, v1, text);
      }
      finishPacket(scene, Material::Atlas, clip, first);
    }
  }
  return scene;
}

void recordRendererSceneFrame(SceneSdlApi &api, SDL_Renderer *renderer,
                              SDL_Texture *target, SDL_Texture *atlas,
                              const Scene &scene, bool present = true) {
  if (!api.SetRenderTarget(renderer, target) ||
      !api.SetRenderScale(renderer, 2.0F, 2.0F) ||
      !api.SetRenderClipRect(renderer, nullptr) ||
      !api.SetRenderDrawColor(renderer, 12, 17, 29, 255) ||
      !api.RenderClear(renderer)) {
    fail(api, "prepare D3D11 representative scene");
  }

  for (const Packet &packet : scene.packets) {
    if (!api.SetRenderClipRect(renderer, &packet.clip)) {
      fail(api, "SDL_SetRenderClipRect");
    }
    const Vertex *vertices = scene.vertices.data() + packet.first_vertex;
    SDL_Texture *texture = packet.material == Material::Atlas ? atlas : nullptr;
    const float *uv =
        packet.material == Material::Atlas ? &vertices->u : nullptr;
    if (!api.RenderGeometryRaw(
            renderer, texture, &vertices->x, sizeof(Vertex),
            reinterpret_cast<const SDL_FColor *>(&vertices->r), sizeof(Vertex),
            uv, sizeof(Vertex), static_cast<int>(packet.vertex_count), nullptr,
            0, 0)) {
      fail(api, "SDL_RenderGeometryRaw");
    }
  }

  if (!api.SetRenderClipRect(renderer, nullptr) ||
      !api.SetRenderTarget(renderer, nullptr) ||
      !api.SetRenderScale(renderer, 1.0F, 1.0F) ||
      !api.RenderTexture(renderer, target, nullptr, nullptr)) {
    fail(api, "resolve D3D11 representative scene");
  }
  if (present && !api.RenderPresent(renderer)) {
    fail(api, "present D3D11 representative scene");
  }
}

std::vector<Uint8> captureRendererScene(SceneSdlApi &api,
                                        SDL_Renderer *renderer,
                                        SDL_Texture *target, SDL_Texture *atlas,
                                        const Scene &scene) {
  recordRendererSceneFrame(api, renderer, target, atlas, scene, false);
  SDL_Surface *surface = api.RenderReadPixels(renderer, nullptr);
  if (surface == nullptr) {
    fail(api, "SDL_RenderReadPixels(scene validation)");
  }
  SceneScopeExit surface_guard(
      [&api, surface] { api.DestroySurface(surface); });
  SDL_Surface *rgba = api.ConvertSurface(surface, SDL_PIXELFORMAT_RGBA32);
  if (rgba == nullptr) {
    fail(api, "SDL_ConvertSurface(scene validation)");
  }
  SceneScopeExit rgba_guard([&api, rgba] { api.DestroySurface(rgba); });
  if (rgba->w != scene.width || rgba->h != scene.height ||
      rgba->pixels == nullptr || rgba->pitch < scene.width * 4) {
    throw std::runtime_error("invalid D3D11 scene validation surface");
  }
  std::vector<Uint8> pixels(static_cast<std::size_t>(scene.width) *
                            scene.height * 4);
  const auto *source = static_cast<const Uint8 *>(rgba->pixels);
  for (int row = 0; row < scene.height; ++row) {
    std::memcpy(pixels.data() + static_cast<std::size_t>(row) * scene.width * 4,
                source + static_cast<std::size_t>(row) * rgba->pitch,
                static_cast<std::size_t>(scene.width) * 4);
  }
  return pixels;
}

BatchResult runRendererScene(SceneSdlApi &api, const Options &options,
                             const Scene &scene,
                             std::vector<Uint8> *validation_pixels) {
  SDL_Window *window =
      createProbeWindow(api, options, "CUI scene probe: D3D11 2x SSAA");
  SceneScopeExit window_guard([&api, window] { api.DestroyWindow(window); });
  SDL_Renderer *renderer = api.CreateRenderer(window, "direct3d11");
  if (renderer == nullptr) {
    fail(api, "SDL_CreateRenderer(direct3d11)");
  }
  SceneScopeExit renderer_guard(
      [&api, renderer] { api.DestroyRenderer(renderer); });
  if (!api.SetRenderVSync(renderer, 0) ||
      !api.SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND)) {
    fail(api, "configure D3D11 scene renderer");
  }

  int output_width = 0;
  int output_height = 0;
  if (!api.GetRenderOutputSize(renderer, &output_width, &output_height) ||
      output_width != scene.width || output_height != scene.height) {
    fail(api, "unexpected D3D11 output dimensions");
  }
  SDL_Texture *target = api.CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
                                          SDL_TEXTUREACCESS_TARGET,
                                          output_width * 2, output_height * 2);
  if (target == nullptr) {
    fail(api, "SDL_CreateTexture(scene SSAA target)");
  }
  SceneScopeExit target_guard([&api, target] { api.DestroyTexture(target); });
  if (!api.SetTextureScaleMode(target, SDL_SCALEMODE_LINEAR) ||
      !api.SetTextureBlendMode(target, SDL_BLENDMODE_NONE)) {
    fail(api, "configure scene SSAA target");
  }

  SDL_Texture *atlas =
      api.CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32,
                        SDL_TEXTUREACCESS_STATIC, kAtlasWidth, kAtlasHeight);
  if (atlas == nullptr) {
    fail(api, "SDL_CreateTexture(scene atlas)");
  }
  SceneScopeExit atlas_guard([&api, atlas] { api.DestroyTexture(atlas); });
  if (!api.UpdateTexture(atlas, nullptr, scene.atlas.data(), kAtlasWidth * 4) ||
      !api.SetTextureScaleMode(atlas, SDL_SCALEMODE_LINEAR) ||
      !api.SetTextureBlendMode(atlas, SDL_BLENDMODE_BLEND)) {
    fail(api, "upload/configure scene atlas");
  }

  if (validation_pixels != nullptr) {
    *validation_pixels =
        captureRendererScene(api, renderer, target, atlas, scene);
  }

  for (int frame = 0; frame < options.warmup; ++frame) {
    recordRendererSceneFrame(api, renderer, target, atlas, scene);
  }
  std::vector<double> samples;
  samples.reserve(static_cast<std::size_t>(options.frames));
  const Clock::time_point batch_start = Clock::now();
  for (int frame = 0; frame < options.frames; ++frame) {
    const Clock::time_point start = Clock::now();
    recordRendererSceneFrame(api, renderer, target, atlas, scene);
    samples.push_back(elapsedMs(start, Clock::now()));
  }
  const Clock::time_point submit_end = Clock::now();
  const SDL_Rect pixel{0, 0, 1, 1};
  SDL_Surface *readback = api.RenderReadPixels(renderer, &pixel);
  if (readback == nullptr) {
    fail(api, "SDL_RenderReadPixels(scene drain)");
  }
  api.DestroySurface(readback);
  const Clock::time_point drain_end = Clock::now();
  const char *name = api.GetRendererName(renderer);
  return BatchResult{0,
                     "renderer_scene_ssaa2",
                     name != nullptr ? name : "direct3d11",
                     "",
                     output_width,
                     output_height,
                     static_cast<int>(scene.packets.size()),
                     static_cast<int>(scene.vertices.size()),
                     options.warmup,
                     options.frames,
                     summarize(samples),
                     elapsedMs(submit_end, drain_end),
                     elapsedMs(batch_start, drain_end) / options.frames};
}

SDL_GPUShader *createShader(SceneSdlApi &api, SDL_GPUDevice *device,
                            const unsigned char *code, std::size_t code_size,
                            SDL_GPUShaderStage stage, Uint32 samplers) {
  SDL_GPUShaderCreateInfo info{};
  info.code = code;
  info.code_size = code_size;
  info.entrypoint = "main";
  info.format = SDL_GPU_SHADERFORMAT_DXIL;
  info.stage = stage;
  info.num_samplers = samplers;
  info.num_uniform_buffers = 1;
  SDL_GPUShader *shader = api.CreateGPUShader(device, &info);
  if (shader == nullptr) {
    fail(api, "SDL_CreateGPUShader");
  }
  return shader;
}

SDL_GPUGraphicsPipeline *createPipeline(SceneSdlApi &api, SDL_GPUDevice *device,
                                        SDL_GPUTextureFormat format,
                                        SDL_GPUShader *vertex_shader,
                                        SDL_GPUShader *fragment_shader,
                                        bool textured) {
  SDL_GPUColorTargetDescription target{};
  target.format = format;
  target.blend_state.enable_blend = true;
  target.blend_state.src_color_blendfactor = SDL_GPU_BLENDFACTOR_SRC_ALPHA;
  target.blend_state.dst_color_blendfactor =
      SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
  target.blend_state.color_blend_op = SDL_GPU_BLENDOP_ADD;
  target.blend_state.src_alpha_blendfactor = SDL_GPU_BLENDFACTOR_ONE;
  target.blend_state.dst_alpha_blendfactor =
      SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
  target.blend_state.alpha_blend_op = SDL_GPU_BLENDOP_ADD;
  target.blend_state.color_write_mask = 0xF;

  SDL_GPUVertexBufferDescription buffer{};
  buffer.slot = 0;
  buffer.pitch = sizeof(Vertex);
  buffer.input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX;

  SDL_GPUVertexAttribute attributes[3]{};
  attributes[0].location = 0;
  attributes[0].buffer_slot = 0;
  attributes[0].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2;
  attributes[0].offset = offsetof(Vertex, x);
  attributes[1].location = 1;
  attributes[1].buffer_slot = 0;
  attributes[1].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4;
  attributes[1].offset = offsetof(Vertex, r);
  if (textured) {
    attributes[2].location = 2;
    attributes[2].buffer_slot = 0;
    attributes[2].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2;
    attributes[2].offset = offsetof(Vertex, u);
  }

  SDL_GPUGraphicsPipelineCreateInfo info{};
  info.vertex_shader = vertex_shader;
  info.fragment_shader = fragment_shader;
  info.vertex_input_state.vertex_buffer_descriptions = &buffer;
  info.vertex_input_state.num_vertex_buffers = 1;
  info.vertex_input_state.vertex_attributes = attributes;
  info.vertex_input_state.num_vertex_attributes = textured ? 3 : 2;
  info.primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
  info.rasterizer_state.fill_mode = SDL_GPU_FILLMODE_FILL;
  info.rasterizer_state.cull_mode = SDL_GPU_CULLMODE_NONE;
  info.rasterizer_state.front_face = SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;
  info.rasterizer_state.enable_depth_clip = true;
  info.multisample_state.sample_count = SDL_GPU_SAMPLECOUNT_4;
  info.target_info.color_target_descriptions = &target;
  info.target_info.num_color_targets = 1;
  SDL_GPUGraphicsPipeline *pipeline =
      api.CreateGPUGraphicsPipeline(device, &info);
  if (pipeline == nullptr) {
    fail(api, "SDL_CreateGPUGraphicsPipeline");
  }
  return pipeline;
}

struct GpuResources {
  SDL_GPUDevice *device;
  SDL_Window *window;
  SDL_GPUTexture *multisample;
  SDL_GPUTexture *atlas;
  SDL_GPUSampler *sampler;
  SDL_GPUBuffer *vertices;
  SDL_GPUGraphicsPipeline *solid_pipeline;
  SDL_GPUGraphicsPipeline *texture_pipeline;
  int width;
  int height;
};

void uploadGpuScene(SceneSdlApi &api, SDL_GPUDevice *device,
                    SDL_GPUBuffer *vertex_buffer, SDL_GPUTexture *atlas,
                    const Scene &scene) {
  const Uint32 vertex_bytes =
      static_cast<Uint32>(scene.vertices.size() * sizeof(Vertex));
  const Uint32 atlas_bytes = static_cast<Uint32>(scene.atlas.size());
  SDL_GPUTransferBufferCreateInfo vertex_transfer_info{};
  vertex_transfer_info.usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
  vertex_transfer_info.size = vertex_bytes;
  SDL_GPUTransferBuffer *vertex_transfer =
      api.CreateGPUTransferBuffer(device, &vertex_transfer_info);
  if (vertex_transfer == nullptr) {
    fail(api, "SDL_CreateGPUTransferBuffer(vertices)");
  }
  SceneScopeExit vertex_transfer_guard([&api, device, vertex_transfer] {
    api.ReleaseGPUTransferBuffer(device, vertex_transfer);
  });
  void *mapped = api.MapGPUTransferBuffer(device, vertex_transfer, false);
  if (mapped == nullptr) {
    fail(api, "SDL_MapGPUTransferBuffer(vertices)");
  }
  std::memcpy(mapped, scene.vertices.data(), vertex_bytes);
  api.UnmapGPUTransferBuffer(device, vertex_transfer);

  SDL_GPUTransferBufferCreateInfo atlas_transfer_info{};
  atlas_transfer_info.usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
  atlas_transfer_info.size = atlas_bytes;
  SDL_GPUTransferBuffer *atlas_transfer =
      api.CreateGPUTransferBuffer(device, &atlas_transfer_info);
  if (atlas_transfer == nullptr) {
    fail(api, "SDL_CreateGPUTransferBuffer(atlas)");
  }
  SceneScopeExit atlas_transfer_guard([&api, device, atlas_transfer] {
    api.ReleaseGPUTransferBuffer(device, atlas_transfer);
  });
  mapped = api.MapGPUTransferBuffer(device, atlas_transfer, false);
  if (mapped == nullptr) {
    fail(api, "SDL_MapGPUTransferBuffer(atlas)");
  }
  std::memcpy(mapped, scene.atlas.data(), atlas_bytes);
  api.UnmapGPUTransferBuffer(device, atlas_transfer);

  SDL_GPUCommandBuffer *command = api.AcquireGPUCommandBuffer(device);
  if (command == nullptr) {
    fail(api, "SDL_AcquireGPUCommandBuffer(upload)");
  }
  SDL_GPUCopyPass *copy = api.BeginGPUCopyPass(command);
  if (copy == nullptr) {
    api.CancelGPUCommandBuffer(command);
    fail(api, "SDL_BeginGPUCopyPass(upload)");
  }
  SDL_GPUTransferBufferLocation vertex_source{vertex_transfer, 0};
  SDL_GPUBufferRegion vertex_destination{vertex_buffer, 0, vertex_bytes};
  api.UploadToGPUBuffer(copy, &vertex_source, &vertex_destination, false);
  SDL_GPUTextureTransferInfo atlas_source{};
  atlas_source.transfer_buffer = atlas_transfer;
  atlas_source.pixels_per_row = kAtlasWidth;
  atlas_source.rows_per_layer = kAtlasHeight;
  SDL_GPUTextureRegion atlas_destination{};
  atlas_destination.texture = atlas;
  atlas_destination.w = kAtlasWidth;
  atlas_destination.h = kAtlasHeight;
  atlas_destination.d = 1;
  api.UploadToGPUTexture(copy, &atlas_source, &atlas_destination, false);
  api.EndGPUCopyPass(copy);
  if (!api.SubmitGPUCommandBuffer(command) || !api.WaitForGPUIdle(device)) {
    fail(api, "submit/wait representative-scene upload");
  }
}

SDL_GPUFence *recordGpuSceneFrame(SceneSdlApi &api,
                                  const GpuResources &resources,
                                  const Scene &scene,
                                  SDL_GPUTransferBuffer *download = nullptr,
                                  Uint32 download_row_pixels = 0) {
  SDL_GPUCommandBuffer *command = api.AcquireGPUCommandBuffer(resources.device);
  if (command == nullptr) {
    fail(api, "SDL_AcquireGPUCommandBuffer(scene)");
  }
  SDL_GPUTexture *swapchain = nullptr;
  Uint32 width = 0;
  Uint32 height = 0;
  if (!api.WaitAndAcquireGPUSwapchainTexture(command, resources.window,
                                             &swapchain, &width, &height)) {
    api.CancelGPUCommandBuffer(command);
    fail(api, "SDL_WaitAndAcquireGPUSwapchainTexture(scene)");
  }
  if (swapchain == nullptr || width != static_cast<Uint32>(resources.width) ||
      height != static_cast<Uint32>(resources.height)) {
    if (!api.SubmitGPUCommandBuffer(command)) {
      fail(api, "submit unavailable/changed scene swapchain");
    }
    throw std::runtime_error(
        "representative-scene swapchain unavailable/changed");
  }

  SDL_GPUColorTargetInfo target{};
  target.texture = resources.multisample;
  target.clear_color = SDL_FColor{0.047F, 0.067F, 0.114F, 1.0F};
  target.load_op = SDL_GPU_LOADOP_CLEAR;
  target.store_op = SDL_GPU_STOREOP_RESOLVE;
  target.resolve_texture = swapchain;
  target.cycle = true;
  SDL_GPURenderPass *pass =
      api.BeginGPURenderPass(command, &target, 1, nullptr);
  if (pass == nullptr) {
    failAfterSwapchainAcquire(api, command, "SDL_BeginGPURenderPass(scene)");
  }

  SDL_GPUViewport viewport{0.0F,
                           0.0F,
                           static_cast<float>(resources.width),
                           static_cast<float>(resources.height),
                           0.0F,
                           1.0F};
  api.SetGPUViewport(pass, &viewport);
  SDL_GPUBufferBinding vertex_binding{resources.vertices, 0};
  api.BindGPUVertexBuffers(pass, 0, &vertex_binding, 1);

  float transform[4][4]{};
  transform[0][0] = 2.0F / resources.width;
  transform[1][1] = -2.0F / resources.height;
  transform[2][2] = 1.0F;
  transform[3][0] = -1.0F;
  transform[3][1] = 1.0F;
  transform[3][3] = 1.0F;
  api.PushGPUVertexUniformData(command, 0, transform, sizeof(transform));
  const float color_scale = 1.0F;
  api.PushGPUFragmentUniformData(command, 0, &color_scale, sizeof(color_scale));

  SDL_GPUTextureSamplerBinding atlas_binding{resources.atlas,
                                             resources.sampler};
  Material bound_material = Material::Atlas;
  bool has_bound_pipeline = false;
  for (const Packet &packet : scene.packets) {
    if (!has_bound_pipeline || packet.material != bound_material) {
      if (packet.material == Material::Atlas) {
        api.BindGPUGraphicsPipeline(pass, resources.texture_pipeline);
        api.BindGPUFragmentSamplers(pass, 0, &atlas_binding, 1);
      } else {
        api.BindGPUGraphicsPipeline(pass, resources.solid_pipeline);
      }
      bound_material = packet.material;
      has_bound_pipeline = true;
    }
    api.SetGPUScissor(pass, &packet.clip);
    api.DrawGPUPrimitives(pass, packet.vertex_count, 1, packet.first_vertex, 0);
  }
  api.EndGPURenderPass(pass);
  if (download != nullptr) {
    SDL_GPUCopyPass *copy = api.BeginGPUCopyPass(command);
    if (copy == nullptr) {
      failAfterSwapchainAcquire(api, command,
                                "SDL_BeginGPUCopyPass(scene validation)");
    }
    SDL_GPUTextureRegion source{};
    source.texture = swapchain;
    source.w = width;
    source.h = height;
    source.d = 1;
    SDL_GPUTextureTransferInfo destination{};
    destination.transfer_buffer = download;
    destination.pixels_per_row = download_row_pixels;
    destination.rows_per_layer = height;
    api.DownloadFromGPUTexture(copy, &source, &destination);
    api.EndGPUCopyPass(copy);
    SDL_GPUFence *fence = api.SubmitGPUCommandBufferAndAcquireFence(command);
    if (fence == nullptr) {
      fail(api, "SDL_SubmitGPUCommandBufferAndAcquireFence(scene validation)");
    }
    return fence;
  }
  if (!api.SubmitGPUCommandBuffer(command)) {
    fail(api, "SDL_SubmitGPUCommandBuffer(scene)");
  }
  return nullptr;
}

std::vector<Uint8> captureGpuScene(SceneSdlApi &api,
                                   const GpuResources &resources,
                                   const Scene &scene,
                                   SDL_GPUTextureFormat format) {
  const Uint32 row_pixels =
      (static_cast<Uint32>(scene.width) + Uint32(63)) & ~Uint32(63);
  const Uint32 byte_count =
      row_pixels * static_cast<Uint32>(scene.height) * Uint32(4);
  SDL_GPUTransferBufferCreateInfo info{};
  info.usage = SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD;
  info.size = byte_count;
  SDL_GPUTransferBuffer *download =
      api.CreateGPUTransferBuffer(resources.device, &info);
  if (download == nullptr) {
    fail(api, "SDL_CreateGPUTransferBuffer(scene validation)");
  }
  SceneScopeExit download_guard([&api, &resources, download] {
    api.ReleaseGPUTransferBuffer(resources.device, download);
  });
  SDL_GPUFence *fence =
      recordGpuSceneFrame(api, resources, scene, download, row_pixels);
  SceneScopeExit fence_guard([&api, &resources, fence] {
    api.ReleaseGPUFence(resources.device, fence);
  });
  SDL_GPUFence *fences[] = {fence};
  if (!api.WaitForGPUFences(resources.device, true, fences, 1)) {
    fail(api, "SDL_WaitForGPUFences(scene validation)");
  }
  const auto *mapped = static_cast<const Uint8 *>(
      api.MapGPUTransferBuffer(resources.device, download, false));
  if (mapped == nullptr) {
    fail(api, "SDL_MapGPUTransferBuffer(scene validation)");
  }
  std::vector<Uint8> pixels(static_cast<std::size_t>(scene.width) *
                            scene.height * 4);
  const bool bgra = format == SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM ||
                    format == SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM_SRGB;
  const bool rgba = format == SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM ||
                    format == SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM_SRGB;
  if (!bgra && !rgba) {
    api.UnmapGPUTransferBuffer(resources.device, download);
    throw std::runtime_error("unsupported scene validation swapchain format");
  }
  for (int row = 0; row < scene.height; ++row) {
    const Uint8 *source =
        mapped + static_cast<std::size_t>(row) * row_pixels * 4;
    Uint8 *destination =
        pixels.data() + static_cast<std::size_t>(row) * scene.width * 4;
    for (int column = 0; column < scene.width; ++column) {
      const Uint8 *pixel = source + static_cast<std::size_t>(column) * 4;
      Uint8 *converted = destination + static_cast<std::size_t>(column) * 4;
      converted[0] = bgra ? pixel[2] : pixel[0];
      converted[1] = pixel[1];
      converted[2] = bgra ? pixel[0] : pixel[2];
      converted[3] = pixel[3];
    }
  }
  api.UnmapGPUTransferBuffer(resources.device, download);
  return pixels;
}

BatchResult runGpuScene(SceneSdlApi &api, const Options &options,
                        const Scene &scene,
                        std::vector<Uint8> *validation_pixels) {
  SDL_Window *window =
      createProbeWindow(api, options, "CUI scene probe: SDL_GPU 4x MSAA");
  SceneScopeExit window_guard([&api, window] { api.DestroyWindow(window); });
  SDL_GPUDevice *device =
      api.CreateGPUDevice(SDL_GPU_SHADERFORMAT_DXIL, false, "direct3d12");
  if (device == nullptr) {
    fail(api, "SDL_CreateGPUDevice(direct3d12)");
  }
  SceneScopeExit device_guard([&api, device] { api.DestroyGPUDevice(device); });
  if (!api.ClaimWindowForGPUDevice(device, window)) {
    fail(api, "SDL_ClaimWindowForGPUDevice(scene)");
  }
  SceneScopeExit claim_guard([&api, device, window] {
    api.ReleaseWindowFromGPUDevice(device, window);
  });
  if (!api.SetGPUSwapchainParameters(device, window,
                                     SDL_GPU_SWAPCHAINCOMPOSITION_SDR,
                                     SDL_GPU_PRESENTMODE_IMMEDIATE)) {
    fail(api, "SDL_SetGPUSwapchainParameters(scene IMMEDIATE)");
  }

  int output_width = 0;
  int output_height = 0;
  if (!api.GetWindowSizeInPixels(window, &output_width, &output_height) ||
      output_width != scene.width || output_height != scene.height) {
    fail(api, "unexpected SDL_GPU scene output dimensions");
  }
  const SDL_GPUTextureFormat format =
      api.GetGPUSwapchainTextureFormat(device, window);
  if (format == SDL_GPU_TEXTUREFORMAT_INVALID ||
      !api.GPUTextureSupportsSampleCount(device, format,
                                         SDL_GPU_SAMPLECOUNT_4)) {
    fail(api, "4x MSAA support for scene swapchain format");
  }

  SDL_GPUTextureCreateInfo multisample_info{};
  multisample_info.type = SDL_GPU_TEXTURETYPE_2D;
  multisample_info.format = format;
  multisample_info.usage = SDL_GPU_TEXTUREUSAGE_COLOR_TARGET;
  multisample_info.width = output_width;
  multisample_info.height = output_height;
  multisample_info.layer_count_or_depth = 1;
  multisample_info.num_levels = 1;
  multisample_info.sample_count = SDL_GPU_SAMPLECOUNT_4;
  SDL_GPUTexture *multisample = api.CreateGPUTexture(device, &multisample_info);
  if (multisample == nullptr) {
    fail(api, "SDL_CreateGPUTexture(scene MSAA)");
  }
  SceneScopeExit multisample_guard([&api, device, multisample] {
    api.ReleaseGPUTexture(device, multisample);
  });

  SDL_GPUTextureCreateInfo atlas_info{};
  atlas_info.type = SDL_GPU_TEXTURETYPE_2D;
  atlas_info.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
  atlas_info.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER;
  atlas_info.width = kAtlasWidth;
  atlas_info.height = kAtlasHeight;
  atlas_info.layer_count_or_depth = 1;
  atlas_info.num_levels = 1;
  atlas_info.sample_count = SDL_GPU_SAMPLECOUNT_1;
  SDL_GPUTexture *atlas = api.CreateGPUTexture(device, &atlas_info);
  if (atlas == nullptr) {
    fail(api, "SDL_CreateGPUTexture(scene atlas)");
  }
  SceneScopeExit atlas_guard(
      [&api, device, atlas] { api.ReleaseGPUTexture(device, atlas); });

  SDL_GPUSamplerCreateInfo sampler_info{};
  sampler_info.min_filter = SDL_GPU_FILTER_LINEAR;
  sampler_info.mag_filter = SDL_GPU_FILTER_LINEAR;
  sampler_info.mipmap_mode = SDL_GPU_SAMPLERMIPMAPMODE_NEAREST;
  sampler_info.address_mode_u = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
  sampler_info.address_mode_v = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
  sampler_info.address_mode_w = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
  SDL_GPUSampler *sampler = api.CreateGPUSampler(device, &sampler_info);
  if (sampler == nullptr) {
    fail(api, "SDL_CreateGPUSampler(scene atlas)");
  }
  SceneScopeExit sampler_guard(
      [&api, device, sampler] { api.ReleaseGPUSampler(device, sampler); });

  SDL_GPUBufferCreateInfo buffer_info{};
  buffer_info.usage = SDL_GPU_BUFFERUSAGE_VERTEX;
  buffer_info.size =
      static_cast<Uint32>(scene.vertices.size() * sizeof(Vertex));
  SDL_GPUBuffer *vertices = api.CreateGPUBuffer(device, &buffer_info);
  if (vertices == nullptr) {
    fail(api, "SDL_CreateGPUBuffer(scene vertices)");
  }
  SceneScopeExit vertices_guard(
      [&api, device, vertices] { api.ReleaseGPUBuffer(device, vertices); });

  SDL_GPUShader *solid_vertex =
      createShader(api, device, tri_color_vert_dxil, tri_color_vert_dxil_len,
                   SDL_GPU_SHADERSTAGE_VERTEX, 0);
  SceneScopeExit solid_vertex_guard([&api, device, solid_vertex] {
    api.ReleaseGPUShader(device, solid_vertex);
  });
  SDL_GPUShader *texture_vertex =
      createShader(api, device, tri_texture_vert_dxil,
                   tri_texture_vert_dxil_len, SDL_GPU_SHADERSTAGE_VERTEX, 0);
  SceneScopeExit texture_vertex_guard([&api, device, texture_vertex] {
    api.ReleaseGPUShader(device, texture_vertex);
  });
  SDL_GPUShader *solid_fragment =
      createShader(api, device, color_frag_dxil, color_frag_dxil_len,
                   SDL_GPU_SHADERSTAGE_FRAGMENT, 0);
  SceneScopeExit solid_fragment_guard([&api, device, solid_fragment] {
    api.ReleaseGPUShader(device, solid_fragment);
  });
  SDL_GPUShader *texture_fragment =
      createShader(api, device, texture_rgba_frag_dxil,
                   texture_rgba_frag_dxil_len, SDL_GPU_SHADERSTAGE_FRAGMENT, 1);
  SceneScopeExit texture_fragment_guard([&api, device, texture_fragment] {
    api.ReleaseGPUShader(device, texture_fragment);
  });

  SDL_GPUGraphicsPipeline *solid_pipeline =
      createPipeline(api, device, format, solid_vertex, solid_fragment, false);
  SceneScopeExit solid_pipeline_guard([&api, device, solid_pipeline] {
    api.ReleaseGPUGraphicsPipeline(device, solid_pipeline);
  });
  SDL_GPUGraphicsPipeline *texture_pipeline = createPipeline(
      api, device, format, texture_vertex, texture_fragment, true);
  SceneScopeExit texture_pipeline_guard([&api, device, texture_pipeline] {
    api.ReleaseGPUGraphicsPipeline(device, texture_pipeline);
  });

  uploadGpuScene(api, device, vertices, atlas, scene);
  const GpuResources resources{
      device,   window,         multisample,      atlas,        sampler,
      vertices, solid_pipeline, texture_pipeline, output_width, output_height};
  if (validation_pixels != nullptr) {
    *validation_pixels = captureGpuScene(api, resources, scene, format);
  }
  for (int frame = 0; frame < options.warmup; ++frame) {
    const auto fence = recordGpuSceneFrame(api, resources, scene);
    if (fence != nullptr) {
      throw std::runtime_error("unexpected fence in GPU scene warmup");
    }
  }
  if (!api.WaitForGPUIdle(device)) {
    fail(api, "SDL_WaitForGPUIdle(scene warmup)");
  }

  std::vector<double> samples;
  samples.reserve(static_cast<std::size_t>(options.frames));
  const Clock::time_point batch_start = Clock::now();
  for (int frame = 0; frame < options.frames; ++frame) {
    const Clock::time_point start = Clock::now();
    const auto fence = recordGpuSceneFrame(api, resources, scene);
    if (fence != nullptr) {
      throw std::runtime_error("unexpected fence in measured GPU scene");
    }
    samples.push_back(elapsedMs(start, Clock::now()));
  }
  const Clock::time_point submit_end = Clock::now();
  if (!api.WaitForGPUIdle(device)) {
    fail(api, "SDL_WaitForGPUIdle(scene measured)");
  }
  const Clock::time_point drain_end = Clock::now();
  const char *driver = api.GetGPUDeviceDriver(device);
  const SDL_PropertiesID properties = api.GetGPUDeviceProperties(device);
  const char *device_name =
      properties != 0 ? api.GetStringProperty(
                            properties, SDL_PROP_GPU_DEVICE_NAME_STRING, "")
                      : "";
  return BatchResult{0,
                     "gpu_scene_msaa4",
                     driver != nullptr ? driver : "direct3d12",
                     device_name != nullptr ? device_name : "",
                     output_width,
                     output_height,
                     static_cast<int>(scene.packets.size()),
                     static_cast<int>(scene.vertices.size()),
                     options.warmup,
                     options.frames,
                     summarize(samples),
                     elapsedMs(submit_end, drain_end),
                     elapsedMs(batch_start, drain_end) / options.frames};
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

PixelValidation validatePixels(const std::vector<Uint8> &renderer,
                               const std::vector<Uint8> &gpu) {
  if (renderer.empty() || renderer.size() != gpu.size() ||
      (renderer.size() % 4) != 0) {
    throw std::runtime_error(
        "scene validation captures have incompatible sizes");
  }
  std::uint64_t absolute_error = 0;
  std::uint64_t pixels_over_16 = 0;
  std::uint64_t renderer_content = 0;
  std::uint64_t gpu_content = 0;
  int max_error = 0;
  const std::size_t pixel_count = renderer.size() / 4;
  for (std::size_t pixel = 0; pixel < pixel_count; ++pixel) {
    int pixel_max = 0;
    for (std::size_t channel = 0; channel < 4; ++channel) {
      const std::size_t offset = pixel * 4 + channel;
      const int difference =
          std::abs(static_cast<int>(renderer[offset]) - gpu[offset]);
      absolute_error += static_cast<std::uint64_t>(difference);
      pixel_max = std::max(pixel_max, difference);
      max_error = std::max(max_error, difference);
    }
    if (pixel_max > 16) {
      ++pixels_over_16;
    }
    const auto is_content = [pixel](const std::vector<Uint8> &pixels) {
      const std::size_t offset = pixel * 4;
      return std::abs(static_cast<int>(pixels[offset]) - 12) > 4 ||
             std::abs(static_cast<int>(pixels[offset + 1]) - 17) > 4 ||
             std::abs(static_cast<int>(pixels[offset + 2]) - 29) > 4;
    };
    if (is_content(renderer)) {
      ++renderer_content;
    }
    if (is_content(gpu)) {
      ++gpu_content;
    }
  }
  const double mean_error = static_cast<double>(absolute_error) /
                            static_cast<double>(renderer.size());
  const double over_ratio =
      static_cast<double>(pixels_over_16) / static_cast<double>(pixel_count);
  const double renderer_content_ratio =
      static_cast<double>(renderer_content) / pixel_count;
  const double gpu_content_ratio =
      static_cast<double>(gpu_content) / pixel_count;
  const bool populated =
      renderer_content_ratio >= 0.20 && gpu_content_ratio >= 0.20;
  const bool similar_coverage =
      std::abs(renderer_content_ratio - gpu_content_ratio) <= 0.03;
  return PixelValidation{mean_error,
                         max_error,
                         over_ratio,
                         renderer_content_ratio,
                         gpu_content_ratio,
                         populated && similar_coverage && mean_error <= 3.0 &&
                             over_ratio <= 0.05};
}

void writePpm(const std::string &path, const std::vector<Uint8> &pixels,
              int width, int height) {
  std::ofstream file(path, std::ios::binary);
  if (!file) {
    throw std::runtime_error("failed to open validation image: " + path);
  }
  file << "P6\n" << width << ' ' << height << "\n255\n";
  for (std::size_t offset = 0; offset < pixels.size(); offset += 4) {
    file.write(reinterpret_cast<const char *>(pixels.data() + offset), 3);
  }
  if (!file) {
    throw std::runtime_error("failed to write validation image: " + path);
  }
}

std::string renderJson(const std::vector<BatchResult> &batches,
                       const PixelValidation &validation,
                       const SceneSdlApi &api) {
  std::vector<double> renderer_complete;
  std::vector<double> gpu_complete;
  std::vector<double> renderer_p95;
  std::vector<double> gpu_p95;
  for (const BatchResult &batch : batches) {
    if (batch.kind == "renderer_scene_ssaa2") {
      renderer_complete.push_back(batch.complete_mean_ms);
      renderer_p95.push_back(batch.submit_ms.p95);
    } else {
      gpu_complete.push_back(batch.complete_mean_ms);
      gpu_p95.push_back(batch.submit_ms.p95);
    }
  }
  const double renderer_median = median(renderer_complete);
  const double gpu_median = median(gpu_complete);
  const double renderer_p95_median = median(renderer_p95);
  const double gpu_p95_median = median(gpu_p95);
  const double speedup = renderer_median / gpu_median;
  const double absolute_saving = renderer_median - gpu_median;
  const bool candidate = validation.passed &&
                         (speedup >= 1.15 || absolute_saving >= 1.0) &&
                         gpu_p95_median <= renderer_p95_median;

  std::ostringstream output;
  output << std::fixed << std::setprecision(6);
  output << "{\n";
  output << "  \"schema\": \"cui.sdl-gpu-scene-probe.v1\",\n";
  output << "  \"sdl_revision\": \"" << jsonEscape(api.GetRevision())
         << "\",\n";
  output << "  \"method\": \"alternating ABBA/BAAB retained command stream; "
            "geometry+scissor+alpha+atlas; IMMEDIATE present; final GPU "
            "drain\",\n";
  output << "  \"batches\": [\n";
  for (std::size_t index = 0; index < batches.size(); ++index) {
    const BatchResult &batch = batches[index];
    output << "    {\"order\": " << index + 1
           << ", \"repeat\": " << batch.repeat << ", \"kind\": \"" << batch.kind
           << "\", \"backend\": \"" << jsonEscape(batch.backend)
           << "\", \"device\": \"" << jsonEscape(batch.device)
           << "\", \"output_width\": " << batch.output_width
           << ", \"output_height\": " << batch.output_height
           << ", \"frame_packets\": " << batch.frame_packets
           << ", \"frame_vertices\": " << batch.frame_vertices
           << ", \"warmup\": " << batch.warmup
           << ", \"frames\": " << batch.frames
           << ", \"submit_ms\": {\"mean\": " << batch.submit_ms.mean
           << ", \"p50\": " << batch.submit_ms.p50
           << ", \"p95\": " << batch.submit_ms.p95
           << ", \"max\": " << batch.submit_ms.maximum
           << "}, \"drain_ms\": " << batch.drain_ms
           << ", \"complete_mean_ms\": " << batch.complete_mean_ms << "}"
           << (index + 1 == batches.size() ? "\n" : ",\n");
  }
  output << "  ],\n";
  output << "  \"pixel_validation\": {\n";
  output << "    \"mean_absolute_error\": " << validation.mean_absolute_error
         << ",\n";
  output << "    \"max_channel_error\": " << validation.max_channel_error
         << ",\n";
  output << "    \"pixels_over_16_ratio\": " << validation.pixels_over_16_ratio
         << ",\n";
  output << "    \"renderer_content_ratio\": "
         << validation.renderer_content_ratio << ",\n";
  output << "    \"gpu_content_ratio\": " << validation.gpu_content_ratio
         << ",\n";
  output << "    \"passed\": " << (validation.passed ? "true" : "false")
         << "\n";
  output << "  },\n";
  output << "  \"aggregate\": {\n";
  output << "    \"renderer_scene_ssaa2_complete_mean_median_ms\": "
         << renderer_median << ",\n";
  output << "    \"gpu_scene_msaa4_complete_mean_median_ms\": " << gpu_median
         << ",\n";
  output << "    \"renderer_over_gpu_speedup\": " << speedup << ",\n";
  output << "    \"absolute_saving_ms\": " << absolute_saving << ",\n";
  output << "    \"renderer_scene_ssaa2_submit_p95_median_ms\": "
         << renderer_p95_median << ",\n";
  output << "    \"gpu_scene_msaa4_submit_p95_median_ms\": " << gpu_p95_median
         << ",\n";
  output << "    \"passes_scene_feasibility_gate\": "
         << (candidate ? "true" : "false") << "\n";
  output << "  },\n";
  output << "  \"interpretation_limit\": \"Synthetic retained scene, not yet "
            "the Cangjie RenderCommand executor or SDL_ttf raster path.\"\n";
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
    } else if (argument == "--dump-prefix") {
      if (++index >= argc) {
        throw std::runtime_error("missing value for --dump-prefix");
      }
      options.dump_prefix = argv[index];
    } else {
      throw std::runtime_error("unknown argument: " + argument);
    }
  }
  if (options.width < 640 || options.height < 400 || options.width > 4096 ||
      options.height > 4096 || options.warmup < 0 || options.frames < 10 ||
      options.repeats < 1) {
    throw std::runtime_error(
        "width/height must be 640x400..4096x4096, repeats positive, warmup "
        "non-negative, and frames at least 10");
  }
  return options;
}

} // namespace

int main(int argc, char **argv) {
  try {
    const Options options = parseOptions(argc, argv);
    SceneSdlApi api(L"SDL3.dll");
    if (!api.Init(SDL_INIT_VIDEO)) {
      fail(api, "SDL_Init(SDL_INIT_VIDEO)");
    }
    SceneScopeExit sdl_guard([&api] { api.Quit(); });
    const Scene scene = makeScene(options.width, options.height);

    std::vector<BatchResult> batches;
    batches.reserve(static_cast<std::size_t>(options.repeats) * 4);
    std::vector<Uint8> renderer_validation;
    std::vector<Uint8> gpu_validation;
    for (int repeat = 1; repeat <= options.repeats; ++repeat) {
      const bool abba = (repeat % 2) == 1;
      for (int slot = 0; slot < 4; ++slot) {
        const bool renderer =
            abba ? (slot == 0 || slot == 3) : (slot == 1 || slot == 2);
        std::vector<Uint8> *capture = nullptr;
        if (renderer && renderer_validation.empty()) {
          capture = &renderer_validation;
        } else if (!renderer && gpu_validation.empty()) {
          capture = &gpu_validation;
        }
        BatchResult batch = renderer
                                ? runRendererScene(api, options, scene, capture)
                                : runGpuScene(api, options, scene, capture);
        batch.repeat = repeat;
        batches.push_back(std::move(batch));
      }
    }

    const PixelValidation validation =
        validatePixels(renderer_validation, gpu_validation);
    if (!options.dump_prefix.empty()) {
      writePpm(options.dump_prefix + "-renderer.ppm", renderer_validation,
               scene.width, scene.height);
      writePpm(options.dump_prefix + "-gpu.ppm", gpu_validation, scene.width,
               scene.height);
    }
    const std::string report = renderJson(batches, validation, api);
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
    std::cerr << "sdl_gpu_scene_probe: " << error.what() << '\n';
    return 1;
  }
}
