# Rivals Assist

Script de cliente em Luau com painel simples, arrastável e animado.

- Aimbot de câmera com ajuste de FOV e suavidade.
- Mira automática para acompanhar alvos sem segurar um botão.
- ESP com contorno, nome, distância em studs e barra de vida.
- Barra de vida animada, com cores de verde a vermelho e vida atual/máxima em HP.
- Filtros de equipe e de visibilidade para a mira.
- Controles por mouse e toque.
- Encerramento com limpeza de efeitos e conexões.

## Carregador

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/vicentzxx/rivals-assist/main/RivalsAssist.client.lua"))()
```

Esse carregador exige um ambiente que disponibilize `loadstring` e `game:HttpGet`.

## Controles

Ative Aimbot e ESP no painel; ambos iniciam desligados.

A barra de vida aparece automaticamente junto ao ESP, abaixo do nome e da distância. O preenchimento acompanha a proporção entre a vida atual e a máxima, e os valores em HP aparecem logo abaixo. A atualização ocorre até dez vezes por segundo.

- **Mira automática (sem segurar):** vem selecionada; basta ligar **Aimbot** para acompanhar alvos dentro do FOV sem pressionar outro botão. Desligue **Aimbot** para parar.
- **Botão direito:** com Mira automática desativada, mantenha pressionado para mirar.
- **SEGURAR MIRA:** controle equivalente para telas de toque no modo manual.
- **Shift direito** ou **R:** mostrar e ocultar o painel.
- **Título do painel:** arraste para mover.
- **X do painel:** encerrar e remover os efeitos.

O FOV é o raio em pixels a partir do centro da tela. Uma suavidade menor deixa a mira mais rápida; uma maior deixa o movimento mais suave.

A mira pausa enquanto você digita, quando a janela perde o foco ou enquanto seu personagem está morto.

## Compatibilidade e validação

A sintaxe foi validada com o compilador Luau. O funcionamento **não foi testado dentro do RIVALS**.

O script usa personagens padrão com `Players.Character`, `Humanoid`, `Head` e `HumanoidRootPart`. O filtro de equipe usa `Team` e `Neutral`; jogos com equipes personalizadas precisam de adaptação. A mira altera apenas a câmera. Disparo e registro de acertos dependem do jogo. Personagens não carregados pelo cliente não podem ser exibidos pelo ESP.

Para testar no Roblox Studio, cole `RivalsAssist.client.lua` em um `LocalScript` dentro de `StarterPlayer > StarterPlayerScripts`. Use um teste com pelo menos dois jogadores.

## Referências

- [Camera](https://create.roblox.com/docs/reference/engine/classes/Camera)
- [Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)
- [CanvasGroup](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup)
- [PlayerGui](https://create.roblox.com/docs/reference/engine/classes/PlayerGui)
