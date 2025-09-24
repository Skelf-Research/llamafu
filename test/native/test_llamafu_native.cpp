#include <gtest/gtest.h>
#include <gmock/gmock.h>
#include "../../android/src/main/cpp/llamafu.h"
#include <string>
#include <vector>
#include <cstring>
#include <fstream>

class LlamafuNativeTest : public ::testing::Test {
protected:
    void SetUp() override {
        llamafu = nullptr;
    }

    void TearDown() override {
        if (llamafu) {
            llamafu_free(llamafu);
            llamafu = nullptr;
        }
    }

    Llamafu llamafu;

    LlamafuModelParams createDefaultModelParams() {
        LlamafuModelParams params = {};
        params.model_path = "test_model.gguf";
        params.n_ctx = 2048;
        params.n_threads = 4;
        params.use_gpu = false;
        params.mmproj_path = nullptr;
        return params;
    }

    void createMockModelFile() {
        std::ofstream file("test_model.gguf");
        file << "mock model data";
        file.close();
    }

    void removeMockModelFile() {
        std::remove("test_model.gguf");
    }
};

TEST_F(LlamafuNativeTest, ValidateStringParamTest) {
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_init(nullptr, &llamafu));

    LlamafuModelParams params = createDefaultModelParams();
    params.model_path = nullptr;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_init(&params, &llamafu));

    params.model_path = "";
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_init(&params, &llamafu));

    std::string long_path(9000, 'a');
    params.model_path = long_path.c_str();
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_init(&params, &llamafu));
}

TEST_F(LlamafuNativeTest, ValidateNumericParamTest) {
    LlamafuModelParams params = createDefaultModelParams();

    params.n_threads = 0;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_init(&params, &llamafu));

    params.n_threads = 129;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_init(&params, &llamafu));

    params.n_threads = 4;
    params.n_ctx = 0;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_init(&params, &llamafu));

    params.n_ctx = 1048577;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_init(&params, &llamafu));
}

TEST_F(LlamafuNativeTest, ModelInitializationWithoutModelFile) {
    LlamafuModelParams params = createDefaultModelParams();
    int32_t result = llamafu_init(&params, &llamafu);
    EXPECT_EQ(LLAMAFU_ERROR_MODEL_LOAD_FAILED, result);
}

TEST_F(LlamafuNativeTest, TokenizeValidation) {
    LlamafuToken* tokens = nullptr;
    int32_t n_tokens = 0;

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_tokenize(nullptr, "test", &tokens, &n_tokens));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_tokenize(llamafu, nullptr, &tokens, &n_tokens));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_tokenize(llamafu, "", &tokens, &n_tokens));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_tokenize(llamafu, "test", nullptr, &n_tokens));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_tokenize(llamafu, "test", &tokens, nullptr));
}

TEST_F(LlamafuNativeTest, DetokenizeValidation) {
    char* text = nullptr;
    LlamafuToken tokens[] = {1, 2, 3};

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_detokenize(nullptr, tokens, 3, &text));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_detokenize(llamafu, nullptr, 3, &text));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_detokenize(llamafu, tokens, 0, &text));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_detokenize(llamafu, tokens, -1, &text));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_detokenize(llamafu, tokens, 32769, &text));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_detokenize(llamafu, tokens, 3, nullptr));
}

TEST_F(LlamafuNativeTest, InferenceParameterValidation) {
    char* result = nullptr;
    LlamafuInferParams params = {};

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(nullptr, &params, &result));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(llamafu, nullptr, &result));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(llamafu, &params, nullptr));

    params.prompt = "test prompt";
    params.max_tokens = 0;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(llamafu, &params, &result));

    params.max_tokens = 32769;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(llamafu, &params, &result));

    params.max_tokens = 100;
    params.temperature = -0.1f;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(llamafu, &params, &result));

    params.temperature = 2.1f;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(llamafu, &params, &result));

    params.temperature = 0.7f;
    params.top_p = -0.1f;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(llamafu, &params, &result));

    params.top_p = 1.1f;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(llamafu, &params, &result));

    params.top_p = 0.9f;
    params.top_k = 0;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(llamafu, &params, &result));

    params.top_k = 201;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(llamafu, &params, &result));

    params.top_k = 40;
    params.repeat_penalty = 0.05f;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(llamafu, &params, &result));

    params.repeat_penalty = 2.1f;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_complete(llamafu, &params, &result));
}

TEST_F(LlamafuNativeTest, LoRAAdapterValidation) {
    LlamafuLoraAdapter adapter;

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_load_lora_adapter_from_file(nullptr, "test.bin", 1.0f, &adapter));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_load_lora_adapter_from_file(llamafu, nullptr, 1.0f, &adapter));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_load_lora_adapter_from_file(llamafu, "", 1.0f, &adapter));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_load_lora_adapter_from_file(llamafu, "test.bin", 1.0f, nullptr));

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_load_lora_adapter_from_file(llamafu, "test.bin", -0.1f, &adapter));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_load_lora_adapter_from_file(llamafu, "test.bin", 2.1f, &adapter));

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_set_lora_adapter(nullptr, adapter, 1.0f));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_set_lora_adapter(llamafu, nullptr, 1.0f));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_set_lora_adapter(llamafu, adapter, -0.1f));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_set_lora_adapter(llamafu, adapter, 2.1f));

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_unload_lora_adapter(nullptr, adapter));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_unload_lora_adapter(llamafu, nullptr));
}

TEST_F(LlamafuNativeTest, MultimodalParameterValidation) {
    char* result = nullptr;
    LlamafuMultimodalInferParams params = {};

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_multimodal_complete(nullptr, &params, &result));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_multimodal_complete(llamafu, nullptr, &result));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_multimodal_complete(llamafu, &params, nullptr));
}

TEST_F(LlamafuNativeTest, ImageProcessingValidation) {
    LlamafuImageFormat format;

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_detect_image_format(nullptr, 100, &format));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_detect_image_format((const uint8_t*)"data", 0, &format));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_detect_image_format((const uint8_t*)"data", 4, nullptr));

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_validate_image_data(nullptr, 100));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_validate_image_data((const uint8_t*)"data", 0));

    char* base64_out = nullptr;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_encode_image_to_base64(nullptr, 100, &base64_out));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_encode_image_to_base64((const uint8_t*)"data", 0, &base64_out));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_encode_image_to_base64((const uint8_t*)"data", 4, nullptr));

    uint8_t* image_out = nullptr;
    size_t out_size = 0;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_decode_base64_to_image(nullptr, &image_out, &out_size));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_decode_base64_to_image("", &image_out, &out_size));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_decode_base64_to_image("validbase64", nullptr, &out_size));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_decode_base64_to_image("validbase64", &image_out, nullptr));
}

TEST_F(LlamafuNativeTest, AudioProcessingValidation) {
    LlamafuAudioFormat format;

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_detect_audio_format(nullptr, 100, &format));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_detect_audio_format((const uint8_t*)"data", 0, &format));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_detect_audio_format((const uint8_t*)"data", 4, nullptr));

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_validate_audio_data(nullptr, 100));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_validate_audio_data((const uint8_t*)"data", 0));

    LlamafuAudioStreamHandle stream = nullptr;
    LlamafuAudioStreamConfig config = {};
    config.sample_rate = 44100;
    config.channels = 2;
    config.format = LLAMAFU_AUDIO_FORMAT_PCM_F32;

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_create_audio_stream(nullptr, &config, nullptr, &stream));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_create_audio_stream(llamafu, nullptr, nullptr, &stream));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_create_audio_stream(llamafu, &config, nullptr, nullptr));

    config.sample_rate = 0;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_create_audio_stream(llamafu, &config, nullptr, &stream));
}

TEST_F(LlamafuNativeTest, StructuredOutputValidation) {
    LlamafuStructuredOutputHandle handle = nullptr;
    LlamafuStructuredOutputConfig config = {};

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_create_structured_output(nullptr, &config, &handle));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_create_structured_output(llamafu, nullptr, &handle));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_create_structured_output(llamafu, &config, nullptr));

    config.format = LLAMAFU_STRUCTURED_FORMAT_JSON;
    config.schema = nullptr;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_create_structured_output(llamafu, &config, &handle));

    config.schema = "";
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_create_structured_output(llamafu, &config, &handle));

    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_validate_structured_output(nullptr, "{}"));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_validate_structured_output(handle, nullptr));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_validate_structured_output(handle, ""));
}

TEST_F(LlamafuNativeTest, MemoryManagementTest) {
    char* test_string = nullptr;
    LlamafuToken* test_tokens = nullptr;
    float* test_embeddings = nullptr;

    llamafu_free_string(nullptr);
    llamafu_free_tokens(nullptr);
    llamafu_free_embeddings(nullptr);

    test_string = (char*)malloc(10);
    strcpy(test_string, "test");
    llamafu_free_string(test_string);

    test_tokens = (LlamafuToken*)malloc(sizeof(LlamafuToken) * 5);
    llamafu_free_tokens(test_tokens);

    test_embeddings = (float*)malloc(sizeof(float) * 100);
    llamafu_free_embeddings(test_embeddings);
}

TEST_F(LlamafuNativeTest, ContextManagementValidation) {
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_get_model_info(nullptr, nullptr));

    LlamafuModelInfo info;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_get_model_info(nullptr, &info));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_get_model_info(llamafu, nullptr));

    float* embeddings = nullptr;
    int32_t n_embd = 0;
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_get_embeddings(nullptr, "test", &embeddings, &n_embd));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_get_embeddings(llamafu, nullptr, &embeddings, &n_embd));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_get_embeddings(llamafu, "", &embeddings, &n_embd));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_get_embeddings(llamafu, "test", nullptr, &n_embd));
    EXPECT_EQ(LLAMAFU_ERROR_INVALID_PARAM, llamafu_get_embeddings(llamafu, "test", &embeddings, nullptr));
}

TEST_F(LlamafuNativeTest, GrammarSamplerTest) {
    LlamafuGrammarSampler sampler = llamafu_grammar_sampler_init(nullptr, "grammar", "root");
    EXPECT_EQ(nullptr, sampler);

    sampler = llamafu_grammar_sampler_init(llamafu, nullptr, "root");
    EXPECT_EQ(nullptr, sampler);

    sampler = llamafu_grammar_sampler_init(llamafu, "", "root");
    EXPECT_EQ(nullptr, sampler);

    sampler = llamafu_grammar_sampler_init(llamafu, "grammar", nullptr);
    EXPECT_EQ(nullptr, sampler);

    sampler = llamafu_grammar_sampler_init(llamafu, "grammar", "");
    EXPECT_EQ(nullptr, sampler);

    llamafu_grammar_sampler_free(nullptr);
}

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}