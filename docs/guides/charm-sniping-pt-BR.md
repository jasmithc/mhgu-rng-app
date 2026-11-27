# Guia de Charm Sniping no MHGU

[English](charm-sniping-en.md) | [Português (Brasil)](charm-sniping-pt-BR.md) | [Español](charm-sniping-es.md)

Este guia explica como conseguir talismãs específicos (inclusive God Charms) em Monster Hunter Generations Ultimate usando o **MHGU Charms RNG** e o método de combinação de itens. O aplicativo calcula posições e tempos do RNG; não modifica o jogo nem o save. Não é necessário desbloquear o Switch ou instalar Python.

## 1. Baixe o aplicativo

Baixe o ZIP correspondente ao seu sistema na [versão mais recente](https://github.com/jasmithc/mhgu-rng-app/releases/latest).

- **Windows:** extraia todos os arquivos, mantenha as DLLs junto ao executável e abra MHGU Charms RNG.exe.
- **macOS:** extraia o ZIP e mova o aplicativo para a pasta Applications (Aplicativos).
- Para avisos de segurança, requisitos e instalação opcional no iPhone/iPad, consulte o [README](../../README.md).

Este guia mantém os nomes dos botões e itens em inglês. Deixe **Language** configurado como English.

## 2. Prepare o jogo

- Remova os Palicos que acompanham seu personagem e escolha a atendente da vila Moga para o serviço do quarto (Room Service).
- Leve Combo Book 1, 99 Huskberries e 99 Needleberries. Garanta que a receita de Normal S Lv2 tenha 100% de chance de sucesso e que não haja Normal S Lv2 na bolsa.
- Para Enduring Charms, desbloqueie Juju Melding e leve três talismãs descartáveis de raridade 5–7 (Queen, King ou Dragon). Isso corresponde ao Rank 4.
- Verifique se há espaço no álbum do Switch para um vídeo de 30 segundos.
- Salve na vila Kokoto com tudo preparado. Você voltará a esse save após tentativas malsucedidas.

**Não corra desde o momento em que carregar seu personagem até confirmar o Melding.** Correr pode fazer o RNG avançar de forma imprevisível. Ande sempre, inclusive no caminho até seu quarto. Depois de confirmar o Melding, pode correr normalmente.

## 3. Encontre o talismã desejado

Abra **Charm Search**. Use as opções predefinidas em **God charms** ou escolha manualmente o tipo de talismã, habilidades, pontos e slots. Por exemplo: Enduring, Tenderizer +6, Expert +10, três slots e **Source: Melding**.

- **Exact:** procura uma correspondência exata aos requisitos.
- **At least:** procura talismãs que atendam ou superem os requisitos.

Defina **Start frame** como 0 e escolha a quantidade em **Frames to search** (aumente se não encontrar resultados). Marque **Set Continue Cycles target to the frame found** e clique em **Run**.

Anote o frame do resultado desejado. O primeiro resultado preenche automaticamente **Target frame** no painel de temporizadores; altere-o manualmente se escolher outro resultado. Para praticar, comece com um talismã possível que apareça relativamente cedo na sequência. Para outros tipos, verifique o Melding e os pontos de acerto adequados.

## 4. Calcule os Continue Cycles

Cada vez que você seleciona Continue, o RNG avança aproximadamente 702 posições adicionais. Normalmente, também avança 30 frames por segundo.

A calculadora **Continue Cycles** estima a quantidade de ciclos necessários, deixando cerca de dois minutos de margem. O alvo do **Continue Counter** é atualizado automaticamente.

Comece com **Pace** em 60 BPM. Quando estiver confortável, experimente 75 ou 90 BPM. Acima de 90 BPM, a tela pode não terminar de carregar a tempo de registrar B, e o próximo toque em A pode carregar o personagem acidentalmente.

### Opção Poogie como margem de segurança

A finalidade original de **Poogie?** é reduzir cinco Continue Cycles para dar tempo de remover o Poogie. Nos meus testes bem-sucedidos, não precisei removê-lo, mas marquei essa opção mesmo assim, como margem de segurança.

Recomendo marcá-la mesmo que deixe o Poogie no quarto. Fazer cinco ciclos a menos oferece margem extra caso você selecione Continue vezes demais por acidente ou demore mais que o esperado. É melhor chegar antes e esperar um pouco mais do que ultrapassar o frame alvo.

## 5. Realize os Continue Cycles

1. Feche completamente o MHGU e abra o jogo novamente.
2. Na tela inicial, inicie o **Continue Counter**.
3. A cada sinal sonoro, pressione A em Continue e, quando aparecer a seleção de personagem, pressione B para voltar à tela inicial.
4. Na última contagem (um sinal mais longo e agudo), selecione Continue e carregue o personagem em vez de voltar à tela inicial.

Mantenha um ritmo constante. Para um alvo próximo do início da sequência, talvez não sejam necessários ciclos; carregue o personagem e prossiga.

## 6. Descubra sua posição atual no RNG

### Prepare a combinação

1. Vá até seu quarto andando, sem correr. Remover o Poogie é opcional, conforme os testes mencionados acima.
2. Abra a **Combo List** e localize Normal S Lv2 (Huskberry + Needleberry).
3. Pressione A **uma vez** para selecionar a receita e abrir o pequeno menu Combine. **Ainda não inicie o Stopwatch.**

### Combine os itens e cronometre

1. Com o pequeno menu Combine já aberto, prepare o **Stopwatch** do aplicativo (use Reset se necessário).
2. Pressione A novamente e mantenha o botão pressionado para começar a combinar. **Inicie o Stopwatch exatamente no momento em que começar a segurar A.**
3. Continue segurando A até atingir 99 munições e não ser possível combinar mais.

O primeiro toque abre o menu; o segundo, mantendo A pressionado, inicia as combinações e o Stopwatch.

### Grave e suspenda o jogo

1. Ao atingir 99, solte A.
2. **Pressione e segure o botão de captura do Switch** para salvar um vídeo dos 30 segundos anteriores.
3. Deixe o Stopwatch continuar contando enquanto o vídeo é salvo.
4. **Pressione HOME no Switch e pare o Stopwatch exatamente no mesmo instante.**

Não pare o Stopwatch ao atingir 99 nem ao pressionar o botão de captura. O RNG continua avançando até que o jogo seja suspenso. Mantenha o MHGU suspenso no menu HOME durante as próximas etapas; não feche nem retorne ao jogo.

## 7. Use Item Combo Search

Assista ao vídeo no álbum do Switch. Pause e avance pelo vídeo para anotar cada quantidade diferente de munição, de 0 até 99, na ordem correta.

Exemplo (apenas o início de uma sequência ilustrativa): `0 2 4 7 10 13 16 18 22 25 28 30 32 35 39 42 45 … 99`. Não digite as reticências: use sua própria sequência completa, separando os números por espaços.

1. Abra **Item Combo Search**.
2. Cole os valores registrados no campo de combinações.
3. Defina o início e a quantidade de frames da pesquisa para abranger a posição esperada antes do alvo (ou comece em 0 e pesquise até o alvo, se necessário).
4. Clique em **Run** e anote o frame informado.

Use diretamente o frame informado: a ferramenta já considera os avanços do RNG causados pelas combinações. Não some esses avanços novamente.

Se não houver resultados, aparecerem diferenças inválidas ou um aviso de baixa confiabilidade, revise cada número e o intervalo de pesquisa. O aplicativo também detecta pequenas irregularidades no ritmo das combinações (Frame Stutter); não apague valores só para forçar um resultado. Um intervalo menor ajuda a distinguir correspondências aleatórias.

## 8. Calcule o tempo de espera

Abra **Frame → Wait Time**. Insira o frame alvo, marque **Subtract a baseline frame** e informe o frame retornado pelo Item Combo Search como referência. Também é possível inserir diretamente a diferença sem marcar essa opção.

Exemplo:

| Informação | Frame |
| --- | ---: |
| Alvo | 296260 |
| Resultado do Item Combo Search | 292660 |
| Diferença | 3600 |

A 30 frames por segundo, 3600 frames correspondem a dois minutos. Clique em **Run** para preencher o tempo de espera do **Final Countdown**.

A contagem regressiva calcula automaticamente:

**Tempo restante = Wait Time − Stopwatch + Correction**

Não subtraia o Stopwatch manualmente. Na primeira tentativa, use Correction igual a 0. Se o tempo restante não for positivo ou não houver tempo suficiente para preparar o Melding, reinicie a tentativa com menos Continue Cycles.

## 9. Realize o Melding

1. Com o jogo ainda suspenso, confira os valores de **Final Countdown**.
2. **Retorne ao MHGU e clique em Start Countdown exatamente no mesmo instante.**
3. Vá andando até a atendente do quarto. Não corra.
4. Selecione Juju Melding para Enduring Charms e escolha os três talismãs de raridade 5–7.
5. Avance até a confirmação final, mas ainda não entregue os talismãs.
6. O aplicativo emite um sinal a cada segundo durante os dez segundos finais e um sinal longo ao chegar a zero. **Confirme o Melding nesse último sinal.**

Depois de confirmar o Melding, o resultado já está determinado e é seguro voltar a correr.

## 10. Confira os resultados sem salvar

Complete uma missão para liberar os resultados.

**Não salve depois de completar a missão. Se o jogo perguntar se deseja salvar, escolha No (Não).** Recolha os talismãs do Melding e confira os resultados primeiro.

- Se conseguiu o talismã desejado, salve o jogo.
- Caso contrário, anote os talismãs recebidos (habilidades, pontos e slots; uma captura de tela ajuda) e feche completamente o jogo sem salvar. Recarregue o save preparado anteriormente para tentar novamente.

Não salvar uma tentativa malsucedida preserva os materiais usados nas combinações e os talismãs utilizados no Melding. Salve somente quando estiver satisfeito com o resultado.

## 11. Corrija o timing

Use **Around a Frame** com o frame alvo, o tipo correto de talismã e **Source: Melding** para verificar os talismãs próximos. **Halcyon / Juju Meld** permite conferir todos os resultados previstos para um frame de entrega específico; use Juju e Rank 4 para três talismãs de raridade 5–7.

Compare as previsões com o que recebeu. Se descobrir que confirmou 15 frames tarde demais, coloque **−15 frames** (ou −0,5 segundo) em **Correction** na próxima tentativa. Se confirmou cedo demais, use uma correção positiva. Uma correção positiva aumenta a espera; uma negativa reduz a espera.

Se não conseguir identificar o resultado próximo ao alvo, revise a sequência de combinações, se andou em vez de correr, a sincronização dos cronômetros, o Rank do Melding e o intervalo de pesquisa.

## Checklist rápido

- [ ] Prepare e salve em Kokoto; escolha o talismã alvo.
- [ ] Marque Poogie como margem de segurança e calcule os Continue Cycles.
- [ ] Reinicie o MHGU e realize os ciclos.
- [ ] Carregue o personagem e vá andando até o quarto.
- [ ] Abra o pequeno menu Combine de Normal S Lv2.
- [ ] Segure A e inicie o Stopwatch simultaneamente; combine até 99.
- [ ] Segure o botão de captura para salvar o vídeo de 30 segundos.
- [ ] Pressione HOME e pare o Stopwatch simultaneamente.
- [ ] Insira a sequência completa no Item Combo Search.
- [ ] Calcule Frame → Wait Time e confira Final Countdown.
- [ ] Retorne ao jogo e inicie a contagem regressiva simultaneamente.
- [ ] Vá andando até a atendente e confirme o Melding no último sinal sonoro.
- [ ] Complete uma missão sem salvar; confira os resultados.
- [ ] Salve somente se estiver satisfeito; caso contrário, reinicie sem salvar e ajuste Correction.

## Links úteis

- [Método original de combinação de itens (em inglês)](https://github.com/jasmithc/mhgu-rng/blob/main/docs/combo_snipe.md)
- [Ranks e funcionamento do Melding](https://github.com/jasmithc/mhgu-rng/blob/main/docs/melding.md)
- [Pesquisa original sobre o RNG](https://github.com/apmnnn/mhxx-rng)
- [Tabelas de habilidades dos talismãs](https://mhgu.kiranico.com/charms)
- [Introdução em vídeo de Clobincole](https://www.youtube.com/watch?v=6aXJoX2hKOI)
