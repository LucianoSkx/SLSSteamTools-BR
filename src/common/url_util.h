#pragma once
#include <string>

namespace UrlUtil {

// Keep scheme/host/path for triage; drop userinfo, query and fragment.
// Provider URLs carry pre-authenticated query strings and OAuth codes.
inline std::string Redact(const std::string& url) {
    size_t query = url.find_first_of("?#");
    std::string out = query == std::string::npos ? url : url.substr(0, query);
    size_t scheme = out.find("://");
    if (scheme != std::string::npos) {
        size_t authority = scheme + 3;
        size_t end = out.find('/', authority);
        size_t at = out.find('@', authority);
        if (at != std::string::npos && (end == std::string::npos || at < end))
            out.replace(authority, at - authority, "REDACTED");
    }
    if (query != std::string::npos) out += "?REDACTED";
    return out;
}

} // namespace UrlUtil
