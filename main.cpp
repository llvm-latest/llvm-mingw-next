#include <meta>
#include <print>

using namespace std::string_view_literals;

// clangd std::string_view hover tests
constexpr auto refl_string = std::meta::display_string_of(^^int);
constexpr const char *cstring = "cstring";
constexpr std::string_view constexpr_string() { return "string"; }
constexpr std::string_view constexpr_object = "object";

constexpr std::string_view test_clangd_hover_constexpr_objects[] = {
    constexpr_object,
    constexpr_string(),
    std::string_view{"01"},
    cstring,
    refl_string,
    "02"sv,
    "03",
};

// generate clangd int version hover test
constexpr int constexpr_int() { return 999; }
constexpr int constexpr_object_int = 111;
constexpr int test_clangd_hover_constexpr_objects_int[] = {
    constexpr_object_int,
    constexpr_int(),
    10000,
};

int main() {
  constexpr auto name = std::meta::display_string_of(^^int);
  std::println("^^int => '{}'", name);

  return 0;
}
