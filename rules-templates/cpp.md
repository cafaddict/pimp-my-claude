---
globs: ["*.cpp", "*.hpp", "*.h", "*.cc", "*.cxx"]
---
- Modern C++ (C++17/20/23) idioms and features
- RAII and smart pointers required — no raw new/delete
- Prefer constexpr and const wherever possible
- Use std::optional, std::variant, std::expected over error codes
- Follow Rule of Five/Zero
- Prefer std::string_view and std::span for non-owning references
- clang-format auto-applied on save (PostToolUse hook)
