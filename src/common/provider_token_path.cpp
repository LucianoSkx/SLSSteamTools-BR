#include "cloud_provider.h"
#include "json.h"

std::string ResolveProviderTokenPath(const std::string& configDir,
                                     const std::string& configJson,
                                     const std::string& provider) {
    auto resolvePath = [&configDir](const std::string& path) {
        if (path.empty()) return path;
#ifdef _WIN32
        const bool absolute = (path.size() >= 3 && path[1] == ':' &&
                               (path[2] == '\\' || path[2] == '/')) ||
                              (path.size() >= 2 && path[0] == '\\' && path[1] == '\\');
#else
        const bool absolute = path[0] == '/';
#endif
        if (absolute || configDir.empty()) return path;
        const char last = configDir.back();
        return configDir + ((last == '/' || last == '\\') ? "" : "/") + path;
    };

    if (!configJson.empty()) {
        Json::Value root = Json::Parse(configJson);
        if (root.type == Json::Type::Object) {
            // Folder is configured by a directory, not a credential document.
            if ((provider == "folder" || provider == "local") &&
                root.has("sync_folder_path") &&
                root["sync_folder_path"].type == Json::Type::String &&
                !root["sync_folder_path"].str().empty()) {
                return resolvePath(root["sync_folder_path"].str());
            }
            // 1) Per-provider registry (survives provider switches).
            if (root.has("token_paths") && root["token_paths"].type == Json::Type::Object &&
                root["token_paths"].has(provider) &&
                root["token_paths"][provider].type == Json::Type::String &&
                !root["token_paths"][provider].str().empty()) {
                return resolvePath(root["token_paths"][provider].str());
            }
            // 2) Active provider's token_path (legacy / single-provider path).
            if (root.has("provider") && root["provider"].str() == provider &&
                root.has("token_path") && root["token_path"].type == Json::Type::String &&
                !root["token_path"].str().empty()) {
                return resolvePath(root["token_path"].str());
            }
        }
    }

    // 3) Convention-based fallback. Must match the exact default filenames the
    //    UI writes so a first run works before Settings has persisted an
    //    explicit token_paths entry. Windows and Linux use different names.
    if (provider == "r2")       return resolvePath("r2_credentials.json");
    if (provider == "s3")       return resolvePath("s3_credentials.json");
    if (provider == "folder" || provider == "local") return {};
#ifdef _WIN32
    if (provider == "gdrive")   return resolvePath("google_tokens.json");
    if (provider == "onedrive") return resolvePath("onedrive_tokens.json");
#endif
    return resolvePath("tokens_" + provider + ".json");
}
