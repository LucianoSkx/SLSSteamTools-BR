Plugins Lua do SLSsteam, instalados em `~/.config/SLSsteam/plugins/`.

Scripts: `install-plugins.sh` (copia os `.lua`), `uninstall-plugins.sh`
(apaga só os dois deste repo), `toggle-plugins.sh on|off` (liga/desliga
sem mexer nos arquivos). O `install.sh` principal faz o passo completo.

- `download.lua` — injeta `AdditionalDepots`/`DecryptionKeys` do config e busca MRC em `gmrc.wudrm.com` (HTTP).
- `spliced-tickets.lua` — ticket de posse via appId 7 para jogos com Steam DRM.

Terceiros, fonte anonima (canal #slssteam-plugins). Quebram quando o cliente Steam atualiza.
