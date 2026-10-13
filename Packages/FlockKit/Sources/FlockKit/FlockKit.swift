/// FlockKit — pure-domain core for Flock Block.
///
/// Issue #1 ships the skeleton namespace plus the one layout decision the
/// README already promises: `FlockWorkspaceLayout`, the single seam through
/// which all scene/tray geometry routes. Issue #2 adds the deterministic
/// four-lane wave engine and replay tests. Coins/unlocks and local save follow
/// in issues #4 and #6.
public enum FlockKit {
    /// Namespace marker for the domain layer.
    public static let domain = "FlockKit"

    /// Current build/CI milestone marker consumed by the app's debug surface.
    public static let milestone = "M0-skeleton"
}
