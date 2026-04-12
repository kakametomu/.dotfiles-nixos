{...}: {
  programs.bash = {
    enable = true;
    initExtra = ''
      # Ghosttyシェルインテグレーション（fishなどからbashを起動した場合に有効化）
      if [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; then
        builtin source "$GHOSTTY_RESOURCES_DIR/shell-integration/bash/ghostty.bash"
      fi

      # Weztermシェルインテグレーション（fishなどからbashを起動した場合に有効化）
      if [[ -n "$WEZTERM_PANE" ]] && command -v wezterm &>/dev/null; then
        source <(wezterm shell-integration bash 2>/dev/null)
      fi
    '';
  };
}
