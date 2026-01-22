import Foundation

// MARK: - Path Utilities (Atom A006)

/// Canonical path utilities for worktree enforcement per Phase 2 System Contract.
///
/// **System Contract Guarantees:**
/// - All paths canonicalized via realpath()
/// - Symlink resolution for security boundaries
/// - Worktree containment verification
public struct PathUtilities {

    // MARK: - Canonicalization

    /// Canonicalize a path using realpath(), resolving symlinks.
    ///
    /// - Parameter path: The path to canonicalize
    /// - Returns: The canonical path, or nil if resolution fails
    public static func canonicalize(_ path: String) -> String? {
        let expandedPath = (path as NSString).expandingTildeInPath

        // Use realpath to resolve symlinks and normalize
        if let realPath = realpath(expandedPath, nil) {
            let result = String(cString: realPath)
            free(realPath)
            return result
        }

        // If file doesn't exist, try to resolve parent directory
        let url = URL(fileURLWithPath: expandedPath)
        let parentPath = url.deletingLastPathComponent().path
        let fileName = url.lastPathComponent

        if let parentReal = realpath(parentPath, nil) {
            let result = String(cString: parentReal) + "/" + fileName
            free(parentReal)
            return result
        }

        return nil
    }

    /// Canonicalize and standardize a path.
    /// Unlike canonicalize(), this works for non-existent paths.
    public static func standardize(_ path: String) -> String {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        return url.standardized.path
    }

    // MARK: - Worktree Enforcement

    /// Check if a path is contained within a worktree.
    ///
    /// - Parameters:
    ///   - path: The path to check
    ///   - worktree: The worktree root path
    /// - Returns: True if path is within worktree (after canonicalization)
    public static func isWithinWorktree(_ path: String, worktree: String) -> Bool {
        guard let canonicalPath = canonicalize(path) ?? Optional(standardize(path)),
              let canonicalWorktree = canonicalize(worktree) ?? Optional(standardize(worktree)) else {
            return false
        }

        // Ensure worktree ends with / for prefix matching
        let worktreePrefix = canonicalWorktree.hasSuffix("/") ? canonicalWorktree : canonicalWorktree + "/"

        return canonicalPath == canonicalWorktree || canonicalPath.hasPrefix(worktreePrefix)
    }

    /// Check if a path attempts to escape the worktree via traversal.
    ///
    /// - Parameters:
    ///   - path: The path to check
    ///   - worktree: The worktree root path
    /// - Returns: True if path contains suspicious traversal patterns
    public static func hasTraversalAttempt(_ path: String, worktree: String) -> Bool {
        // Check for obvious traversal patterns
        if path.contains("..") {
            // Resolve the path and check if it escapes
            let resolvedPath = standardize(path)
            if !isWithinWorktree(resolvedPath, worktree: worktree) {
                return true
            }
        }
        return false
    }

    // MARK: - Symlink Detection

    /// Check if a path is a symlink.
    public static func isSymlink(_ path: String) -> Bool {
        var isSymlink = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: nil)

        guard exists else { return false }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.type] as? FileAttributeType == .typeSymbolicLink
        } catch {
            return false
        }
    }

    /// Get the target of a symlink.
    public static func symlinkTarget(_ path: String) -> String? {
        guard isSymlink(path) else { return nil }

        do {
            return try FileManager.default.destinationOfSymbolicLink(atPath: path)
        } catch {
            return nil
        }
    }

    /// Check if path or any parent is a symlink pointing outside worktree.
    ///
    /// - Parameters:
    ///   - path: The path to check
    ///   - worktree: The worktree root path
    /// - Returns: True if any symlink in the path escapes the worktree
    public static func hasSymlinkEscape(_ path: String, worktree: String) -> Bool {
        var currentPath = path
        var visited: Set<String> = []

        while !currentPath.isEmpty && currentPath != "/" {
            // Prevent infinite loops
            if visited.contains(currentPath) { return true }
            visited.insert(currentPath)

            if isSymlink(currentPath) {
                if let target = symlinkTarget(currentPath) {
                    // Resolve relative symlink targets
                    let resolvedTarget: String
                    if target.hasPrefix("/") {
                        resolvedTarget = target
                    } else {
                        let parentDir = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path
                        resolvedTarget = standardize(parentDir + "/" + target)
                    }

                    // Check if symlink escapes worktree
                    if !isWithinWorktree(resolvedTarget, worktree: worktree) {
                        return true
                    }
                }
            }

            currentPath = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path
        }

        return false
    }

    // MARK: - Path Comparison

    /// Compare two paths for equality after canonicalization.
    public static func pathsAreEqual(_ path1: String, _ path2: String) -> Bool {
        let canonical1 = canonicalize(path1) ?? standardize(path1)
        let canonical2 = canonicalize(path2) ?? standardize(path2)
        return canonical1 == canonical2
    }

    /// Get the relative path from base to target.
    public static func relativePath(from base: String, to target: String) -> String? {
        let baseURL = URL(fileURLWithPath: standardize(base))
        let targetURL = URL(fileURLWithPath: standardize(target))

        // Simple implementation - find common prefix and compute relative path
        let baseComponents = baseURL.pathComponents
        let targetComponents = targetURL.pathComponents

        var commonIndex = 0
        for (index, component) in baseComponents.enumerated() {
            if index < targetComponents.count && component == targetComponents[index] {
                commonIndex = index + 1
            } else {
                break
            }
        }

        let upCount = baseComponents.count - commonIndex
        let upComponents = Array(repeating: "..", count: upCount)
        let downComponents = Array(targetComponents[commonIndex...])

        return (upComponents + downComponents).joined(separator: "/")
    }

    // MARK: - File Type Detection

    /// Check if path is a directory.
    public static func isDirectory(_ path: String) -> Bool {
        var isDir = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    /// Check if path exists.
    public static func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    // MARK: - Security Helpers

    /// Validate a path for tool execution, returning risk factors.
    public static func validatePath(
        _ path: String,
        worktree: String?
    ) -> PathValidationResult {
        var issues: [PathIssue] = []

        // Check for traversal attempts
        if path.contains("..") {
            issues.append(.traversalAttempt)
        }

        // Check worktree containment if worktree is specified
        if let worktree = worktree {
            if !isWithinWorktree(path, worktree: worktree) {
                issues.append(.outsideWorktree)
            }

            if hasSymlinkEscape(path, worktree: worktree) {
                issues.append(.symlinkEscape)
            }
        }

        // Check for absolute path when relative expected
        if path.hasPrefix("/") && worktree != nil {
            // Absolute paths are suspicious when we have a worktree
            if !isWithinWorktree(path, worktree: worktree!) {
                issues.append(.absolutePathOutsideWorktree)
            }
        }

        // Check for sensitive paths
        if isSensitivePath(path) {
            issues.append(.sensitivePath)
        }

        return PathValidationResult(
            path: path,
            canonicalPath: canonicalize(path),
            issues: issues
        )
    }

    /// Check if path is a known sensitive location.
    private static func isSensitivePath(_ path: String) -> Bool {
        let sensitivePrefixes = [
            "/etc/",
            "/usr/",
            "/bin/",
            "/sbin/",
            "/var/",
            "/System/",
            "/Library/",
            "~/.ssh/",
            "~/.gnupg/",
            "~/.aws/",
            "~/.kube/",
            "~/.docker/",
        ]

        let expandedPath = (path as NSString).expandingTildeInPath

        for prefix in sensitivePrefixes {
            let expandedPrefix = (prefix as NSString).expandingTildeInPath
            if expandedPath.hasPrefix(expandedPrefix) {
                return true
            }
        }

        // Check for hidden config files in home
        if expandedPath.hasPrefix(NSHomeDirectory()) {
            let relativePath = expandedPath.dropFirst(NSHomeDirectory().count + 1)
            if relativePath.hasPrefix(".") && relativePath.contains("config") {
                return true
            }
        }

        return false
    }
}

// MARK: - Path Validation Result

/// Result of path validation
public struct PathValidationResult: Sendable {
    public let path: String
    public let canonicalPath: String?
    public let issues: [PathIssue]

    public var isValid: Bool { issues.isEmpty }
    public var riskLevel: ToolRiskLevel {
        if issues.isEmpty { return .low }
        if issues.contains(.outsideWorktree) || issues.contains(.symlinkEscape) {
            return .high
        }
        return .medium
    }
}

/// Path validation issues
public enum PathIssue: String, Sendable, CaseIterable {
    case traversalAttempt = "traversal_attempt"
    case outsideWorktree = "outside_worktree"
    case symlinkEscape = "symlink_escape"
    case absolutePathOutsideWorktree = "absolute_path_outside_worktree"
    case sensitivePath = "sensitive_path"

    public var description: String {
        switch self {
        case .traversalAttempt: return "Path contains directory traversal (..)"
        case .outsideWorktree: return "Path is outside the worktree"
        case .symlinkEscape: return "Path contains symlink that escapes worktree"
        case .absolutePathOutsideWorktree: return "Absolute path outside worktree"
        case .sensitivePath: return "Path accesses sensitive system location"
        }
    }
}
