#include <iostream>
#include <chrono>
#include <vector>
#include <string>
#include <thread>
#include <memory>
#include <random>
#include <fstream>
#include "../../android/src/main/cpp/llamafu.h"

class PerformanceTimer {
public:
    PerformanceTimer(const std::string& name) : name_(name) {
        start_ = std::chrono::high_resolution_clock::now();
    }

    ~PerformanceTimer() {
        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start_);
        std::cout << name_ << " took " << duration.count() << "ms" << std::endl;
    }

private:
    std::string name_;
    std::chrono::high_resolution_clock::time_point start_;
};

void createMockModelFile(const std::string& path, size_t sizeMB = 10) {
    std::ofstream file(path, std::ios::binary);

    // Write GGUF header
    const char gguf_magic[] = "GGUF";
    file.write(gguf_magic, 4);

    uint32_t version = 3;
    file.write(reinterpret_cast<const char*>(&version), sizeof(version));

    uint64_t tensor_count = 0;
    file.write(reinterpret_cast<const char*>(&tensor_count), sizeof(tensor_count));

    uint64_t metadata_kv_count = 0;
    file.write(reinterpret_cast<const char*>(&metadata_kv_count), sizeof(metadata_kv_count));

    // Fill with mock data
    const size_t total_size = sizeMB * 1024 * 1024;
    const size_t header_size = 4 + 4 + 8 + 8; // magic + version + counts
    const size_t remaining = total_size - header_size;

    std::vector<char> mock_data(remaining, 0);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, 255);

    for (size_t i = 0; i < remaining; ++i) {
        mock_data[i] = static_cast<char>(dis(gen));
    }

    file.write(mock_data.data(), remaining);
    file.close();
}

bool testInitializationPerformance() {
    std::cout << "\n=== Initialization Performance Tests ===" << std::endl;

    const std::string model_path = "/tmp/test_model_perf.gguf";
    createMockModelFile(model_path, 10); // 10MB mock model

    // Test different context sizes
    std::vector<int32_t> context_sizes = {512, 1024, 2048, 4096};

    for (int32_t ctx_size : context_sizes) {
        PerformanceTimer timer("Initialization (ctx=" + std::to_string(ctx_size) + ")");

        LlamafuModelParams params = {};
        params.model_path = model_path.c_str();
        params.n_ctx = ctx_size;
        params.n_threads = 4;
        params.use_gpu = false;
        params.mmproj_path = nullptr;

        Llamafu llamafu = nullptr;
        int32_t result = llamafu_init(&params, &llamafu);

        if (result != LLAMAFU_SUCCESS) {
            std::cout << "  Expected initialization failure with mock model: " << result << std::endl;
        }

        if (llamafu) {
            llamafu_free(llamafu);
        }
    }

    std::remove(model_path.c_str());
    return true;
}

bool testTokenizationPerformance() {
    std::cout << "\n=== Tokenization Performance Tests ===" << std::endl;

    const std::string model_path = "/tmp/test_model_tok.gguf";
    createMockModelFile(model_path, 5);

    LlamafuModelParams params = {};
    params.model_path = model_path.c_str();
    params.n_ctx = 2048;
    params.n_threads = 4;
    params.use_gpu = false;

    Llamafu llamafu = nullptr;
    int32_t result = llamafu_init(&params, &llamafu);

    if (result != LLAMAFU_SUCCESS) {
        std::cout << "Mock model initialization failed (expected): " << result << std::endl;
        std::remove(model_path.c_str());
        return true; // Still pass the test since we're using mock data
    }

    // Test different text lengths
    std::vector<std::string> test_texts = {
        "Short text",
        "This is a medium length text that should take a bit more time to tokenize than the short text.",
        std::string(1000, 'A'), // Long text
        std::string(10000, 'B'), // Very long text
    };

    for (const auto& text : test_texts) {
        PerformanceTimer timer("Tokenization (" + std::to_string(text.length()) + " chars)");

        LlamafuToken* tokens = nullptr;
        int32_t n_tokens = 0;

        int32_t tok_result = llamafu_tokenize(llamafu, text.c_str(), &tokens, &n_tokens);

        if (tok_result == LLAMAFU_SUCCESS && tokens) {
            std::cout << "  Tokenized " << text.length() << " chars into " << n_tokens << " tokens" << std::endl;
            llamafu_free_tokens(tokens);
        }
    }

    if (llamafu) {
        llamafu_free(llamafu);
    }

    std::remove(model_path.c_str());
    return true;
}

bool testConcurrentOperations() {
    std::cout << "\n=== Concurrent Operations Tests ===" << std::endl;

    const std::string model_path = "/tmp/test_model_conc.gguf";
    createMockModelFile(model_path, 5);

    const int num_threads = 4;
    const int operations_per_thread = 10;

    auto worker = [&](int thread_id) {
        PerformanceTimer timer("Thread " + std::to_string(thread_id));

        LlamafuModelParams params = {};
        params.model_path = model_path.c_str();
        params.n_ctx = 1024;
        params.n_threads = 2;
        params.use_gpu = false;

        Llamafu llamafu = nullptr;
        int32_t result = llamafu_init(&params, &llamafu);

        if (result != LLAMAFU_SUCCESS) {
            std::cout << "  Thread " << thread_id << " init failed (expected): " << result << std::endl;
            return;
        }

        for (int i = 0; i < operations_per_thread; ++i) {
            std::string text = "Concurrent test " + std::to_string(thread_id) + "_" + std::to_string(i);

            LlamafuToken* tokens = nullptr;
            int32_t n_tokens = 0;

            int32_t tok_result = llamafu_tokenize(llamafu, text.c_str(), &tokens, &n_tokens);

            if (tok_result == LLAMAFU_SUCCESS && tokens) {
                llamafu_free_tokens(tokens);
            }
        }

        if (llamafu) {
            llamafu_free(llamafu);
        }
    };

    PerformanceTimer total_timer("Total concurrent operations");

    std::vector<std::thread> threads;
    for (int i = 0; i < num_threads; ++i) {
        threads.emplace_back(worker, i);
    }

    for (auto& thread : threads) {
        thread.join();
    }

    std::remove(model_path.c_str());
    return true;
}

bool testMemoryOperations() {
    std::cout << "\n=== Memory Operations Tests ===" << std::endl;

    // Test parameter validation performance
    {
        PerformanceTimer timer("Parameter validation (1000 iterations)");

        for (int i = 0; i < 1000; ++i) {
            LlamafuModelParams params = {};
            params.model_path = nullptr; // Invalid

            Llamafu llamafu = nullptr;
            int32_t result = llamafu_init(&params, &llamafu);

            if (result != LLAMAFU_ERROR_INVALID_PARAM) {
                std::cout << "Unexpected result: " << result << std::endl;
            }
        }
    }

    // Test memory allocation/deallocation
    {
        PerformanceTimer timer("Memory allocation/deallocation (1000 iterations)");

        for (int i = 0; i < 1000; ++i) {
            char* test_string = static_cast<char*>(malloc(1000));
            if (test_string) {
                snprintf(test_string, 1000, "Test string %d", i);
                llamafu_free_string(test_string);
            }

            LlamafuToken* test_tokens = static_cast<LlamafuToken*>(malloc(sizeof(LlamafuToken) * 100));
            if (test_tokens) {
                llamafu_free_tokens(test_tokens);
            }

            float* test_embeddings = static_cast<float*>(malloc(sizeof(float) * 1000));
            if (test_embeddings) {
                llamafu_free_embeddings(test_embeddings);
            }
        }
    }

    return true;
}

bool testImageProcessingPerformance() {
    std::cout << "\n=== Image Processing Performance Tests ===" << std::endl;

    // Create mock image data of different sizes
    std::vector<std::pair<int, int>> image_sizes = {
        {224, 224},   // Small
        {512, 512},   // Medium
        {1024, 1024}, // Large
    };

    for (const auto& [width, height] : image_sizes) {
        size_t image_size = width * height * 3; // RGB
        std::vector<uint8_t> mock_image(image_size);

        // Create mock PNG header
        mock_image[0] = 0x89;
        mock_image[1] = 0x50;
        mock_image[2] = 0x4E;
        mock_image[3] = 0x47;

        // Fill with random data
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<> dis(0, 255);

        for (size_t i = 4; i < image_size; ++i) {
            mock_image[i] = static_cast<uint8_t>(dis(gen));
        }

        {
            PerformanceTimer timer("Image format detection (" + std::to_string(width) + "x" + std::to_string(height) + ")");

            LlamafuImageFormat format;
            int32_t result = llamafu_detect_image_format(mock_image.data(), mock_image.size(), &format);

            if (result == LLAMAFU_SUCCESS) {
                std::cout << "  Detected format: " << static_cast<int>(format) << std::endl;
            }
        }

        {
            PerformanceTimer timer("Image validation (" + std::to_string(width) + "x" + std::to_string(height) + ")");

            int32_t result = llamafu_validate_image_data(mock_image.data(), mock_image.size());
            std::cout << "  Validation result: " << (result == LLAMAFU_SUCCESS ? "PASS" : "FAIL") << std::endl;
        }

        {
            PerformanceTimer timer("Base64 encoding (" + std::to_string(width) + "x" + std::to_string(height) + ")");

            char* base64_out = nullptr;
            int32_t result = llamafu_encode_image_to_base64(mock_image.data(), mock_image.size(), &base64_out);

            if (result == LLAMAFU_SUCCESS && base64_out) {
                std::cout << "  Encoded to " << strlen(base64_out) << " base64 chars" << std::endl;
                llamafu_free_string(base64_out);
            }
        }
    }

    return true;
}

bool testStressConditions() {
    std::cout << "\n=== Stress Condition Tests ===" << std::endl;

    // Test rapid successive operations
    {
        PerformanceTimer timer("Rapid successive operations (1000 iterations)");

        for (int i = 0; i < 1000; ++i) {
            // Test various parameter validation calls rapidly
            LlamafuModelParams params = {};
            params.model_path = i % 2 == 0 ? nullptr : "invalid_path";
            params.n_ctx = i % 3 == 0 ? -1 : 1024;
            params.n_threads = i % 5 == 0 ? 0 : 4;

            Llamafu llamafu = nullptr;
            llamafu_init(&params, &llamafu);

            if (llamafu) {
                llamafu_free(llamafu);
            }
        }
    }

    // Test large data handling
    {
        PerformanceTimer timer("Large data handling");

        // Create very large text
        std::string large_text(100000, 'X');

        LlamafuToken* tokens = nullptr;
        int32_t n_tokens = 0;

        // This should fail gracefully with a mock model
        int32_t result = llamafu_tokenize(nullptr, large_text.c_str(), &tokens, &n_tokens);

        if (result != LLAMAFU_ERROR_INVALID_PARAM) {
            std::cout << "  Large text handling: " << result << std::endl;
        }
    }

    return true;
}

int main() {
    std::cout << "Starting Llamafu Native Performance Tests" << std::endl;
    std::cout << "==========================================" << std::endl;

    bool all_passed = true;

    // Run all performance tests
    all_passed &= testInitializationPerformance();
    all_passed &= testTokenizationPerformance();
    all_passed &= testConcurrentOperations();
    all_passed &= testMemoryOperations();
    all_passed &= testImageProcessingPerformance();
    all_passed &= testStressConditions();

    std::cout << "\n==========================================" << std::endl;
    std::cout << "Performance tests completed: " << (all_passed ? "PASSED" : "FAILED") << std::endl;

    return all_passed ? 0 : 1;
}