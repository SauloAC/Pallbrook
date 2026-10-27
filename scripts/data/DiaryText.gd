# The old doctor's diary: every sheet, in every language (generated from the design doc)
# whole sheets have "text"; torn sheets have "lines" of [left, right] and a "layout" saying
# which piece (A, B or C) holds each half. A full-width line has the same piece twice and "" right.
const PAGES := [
	{
		"id": 1,
		"whole": true,
		"text": {
			"en": "To whoever follows in my footsteps,\n\nI began this diary because things are happening in Pallbrook that I cannot explain. If something happens to me, I want the one who comes after me not to start from nothing.\n\nI have served Pallbrook for twelve years. I have seen winter fevers, hard births, and lungs ruined by the damp. This sickness is none of these, though it borrows their faces.\n\nExamine each patient properly. Take the pulse. Note the colour of the lips. Look at the neck, and at the wrists, under the sleeve. Look at their clothes too: soot, wax, chalk, ink, wine, a loose thread. One trace proves little.\n\nAsk each of them where they were last night, and what they saw. Ask in the morning, while it is fresh. Do not mistake a ready answer for an honest one.\n\nThe iron tonic in the cabinet gives strength back to the pale. It does nothing for a true fever.\n\nBe back here before one in the morning. Whatever walks Pallbrook after dark is not something to watch from the street.\n\nI used to think these precautions were enough. They were not.\n\n— E. H.",
			"pt_BR": "A quem seguir os meus passos,\n\nComecei este diário porque coisas além da minha compreensão estão acontecendo em Pallbrook. Se algo me acontecer, quero que quem vier depois de mim não comece do zero.\n\nSirvo a Pallbrook há doze anos. Já vi febres de inverno, partos difíceis e pulmões arruinados pela umidade. Esta doença não é nenhuma delas, embora use o rosto de todas.\n\nExamine cada paciente direito. Tome o pulso. Repare na cor dos lábios. Olhe o pescoço, e os pulsos, por baixo da manga. Olhe as roupas também: fuligem, cera, giz, tinta, vinho, um fio solto. Um vestígio só prova pouco.\n\nPergunte a cada um onde estava ontem à noite, e o que viu. Pergunte de manhã, enquanto está fresco. Não confunda uma resposta pronta com uma resposta sincera.\n\nO tônico de ferro do armário devolve as forças aos pálidos. Não faz nada contra uma febre de verdade.\n\nVolte para cá antes da uma da manhã. O que anda por Pallbrook depois que escurece não é coisa para se observar parado na rua.\n\nEu achava que esses cuidados bastavam. Não bastaram.\n\n— E. H.",
			"es": "A quien siga mis pasos:\n\nEmpecé este diario porque en Pallbrook están pasando cosas que no sé explicar. Si algo me ocurre, quiero que quien venga después de mí no empiece desde cero.\n\nSirvo a Pallbrook desde hace doce años. He visto fiebres de invierno, partos difíciles y pulmones arruinados por la humedad. Esta enfermedad no es ninguna de ellas, aunque tome prestada su cara.\n\nExamine bien a cada paciente. Tome el pulso. Fíjese en el color de los labios. Mire el cuello, y las muñecas, bajo la manga. Mire también la ropa: hollín, cera, tiza, tinta, vino, un hilo suelto. Un rastro solo prueba poco.\n\nPregunte a cada uno dónde estuvo anoche y qué vio. Pregunte por la mañana, mientras está fresco. No confunda una respuesta preparada con una sincera.\n\nEl tónico de hierro del armario devuelve las fuerzas a los pálidos. No hace nada contra una fiebre de verdad.\n\nVuelva aquí antes de la una de la madrugada. Lo que anda por Pallbrook al caer la noche no es algo para observar parado en la calle.\n\nYo creía que estas precauciones bastaban. No bastaron.\n\n— E. H.",
			"ja": "私の後を継ぐ者へ\n\nこの日記を書き始めたのは、パルブルックで私には説明のつかないことが起きているからだ。もし私の身に何かあっても、後に来る者がゼロから始めずに済むように。\n\n私は十二年、パルブルックに仕えてきた。冬の熱病も、難産も、湿気に冒された肺も見てきた。この病はそのどれでもない。ただ、それらの顔を借りているだけだ。\n\n患者は一人ひとりきちんと診ること。脈を取れ。唇の色を見よ。首を、そして袖の下の手首を見よ。服も見ること。煤、蝋、白墨、インク、ワイン、ほつれた糸。痕跡ひとつでは、ほとんど何も証明できない。\n\n昨夜どこにいたか、何を見たかを一人ひとりに尋ねよ。記憶が新しいうちに、朝のうちに。用意された答えを正直な答えと取り違えるな。\n\n戸棚の鉄剤は青ざめた者に力を戻す。本物の熱には効かない。\n\n午前一時までにはここへ戻れ。日が暮れてからパルブルックを歩くものは、通りに立って眺めていい相手ではない。\n\nこれだけ用心すれば十分だと思っていた。十分ではなかった。\n\n— E. H."
		},
		"title": {
			"en": "To the next doctor",
			"pt_BR": "Ao próximo médico",
			"es": "Al próximo médico",
			"ja": "次の医師へ"
		}
	},
	{
		"id": 2,
		"lore": "servants",
		"layout": [
			[
				"A",
				"B"
			],
			[
				"A",
				"B"
			],
			[
				"A",
				"B"
			],
			[
				"A",
				"B"
			],
			[
				"C",
				"B"
			],
			[
				"C",
				"B"
			],
			[
				"C",
				"B"
			]
		],
		"places": {
			"B": [
				"Taverna",
				"Igreja"
			],
			"C": [
				"Escola",
				"Prefeitura"
			]
		},
		"title": {
			"en": "The grateful patient",
			"pt_BR": "A paciente agradecida",
			"es": "La paciente agradecida",
			"ja": "感謝する患者"
		},
		"learned": {
			"en": "Some of the bitten lie for it, and point at the innocent.",
			"pt_BR": "Alguns mordidos mentem por ele e apontam para inocentes.",
			"es": "Algunos mordidos mienten por él y señalan a inocentes.",
			"ja": "噛まれた者の中には、それのために嘘をつき、罪のない者を指さす者がいる。"
		},
		"lines": {
			"en": [
				[
					"A woman I nursed through",
					"the worst of it"
				],
				[
					"rose from her bed today.",
					"Pulse weak, colour good."
				],
				[
					"I asked who had come",
					"to her that night."
				],
				[
					"She named a neighbour,",
					"and swore no harm was done."
				],
				[
					"I asked again an hour later.",
					"Same words, same order,"
				],
				[
					"as if learned by heart. Not all who",
					"survive it are free:"
				],
				[
					"some lie for it after,",
					"and point at the innocent."
				]
			],
			"pt_BR": [
				[
					"Uma mulher que tratei",
					"no pior da doença"
				],
				[
					"levantou da cama hoje.",
					"Pulso fraco, cor boa."
				],
				[
					"Perguntei quem tinha vindo",
					"até ela naquela noite."
				],
				[
					"Ela disse o nome de um vizinho,",
					"e jurou que não houve mal."
				],
				[
					"Perguntei de novo uma hora depois.",
					"Mesmas palavras, mesma ordem,"
				],
				[
					"como se decoradas. Nem todo",
					"sobrevivente fica livre:"
				],
				[
					"alguns mentem por ele depois,",
					"e apontam para inocentes."
				]
			],
			"es": [
				[
					"Una mujer a la que cuidé",
					"en lo peor de la enfermedad"
				],
				[
					"se levantó hoy de la cama.",
					"Pulso débil, buen color."
				],
				[
					"Le pregunté quién había ido",
					"a verla aquella noche."
				],
				[
					"Nombró a un vecino,",
					"y juró que no hubo daño."
				],
				[
					"Volví a preguntar una hora después.",
					"Mismas palabras, mismo orden,"
				],
				[
					"como aprendidas de memoria. No todo",
					"el que sobrevive queda libre:"
				],
				[
					"algunos mienten por él después,",
					"y señalan a inocentes."
				]
			],
			"ja": [
				[
					"最悪の時期を看病した女が",
					"今日、床から起き上がった。"
				],
				[
					"脈は弱いが、",
					"顔色は良い。"
				],
				[
					"あの夜、誰が",
					"訪ねてきたのかと尋ねた。"
				],
				[
					"彼女は隣人の名を挙げ、",
					"何も害はなかったと誓った。"
				],
				[
					"一時間後にもう一度尋ねた。",
					"同じ言葉、同じ順序。"
				],
				[
					"まるで暗記したかのように。生き延びた者が",
					"皆自由なわけではない。"
				],
				[
					"後になってそれのために嘘をつき、",
					"罪のない者を指さす者もいる。"
				]
			]
		}
	},
	{
		"id": 3,
		"lore": "traces",
		"layout": [
			[
				"A",
				"A"
			],
			[
				"A",
				"B"
			],
			[
				"B",
				"C"
			],
			[
				"B",
				"C"
			],
			[
				"B",
				"C"
			],
			[
				"B",
				"C"
			]
		],
		"places": {
			"B": [
				"Biblioteca",
				"Praca"
			],
			"C": [
				"Prefeitura",
				"Taverna"
			]
		},
		"title": {
			"en": "The stain",
			"pt_BR": "A mancha",
			"es": "La mancha",
			"ja": "染み"
		},
		"learned": {
			"en": "The same trace on two victims is a signature.",
			"pt_BR": "O mesmo vestígio em duas vítimas é uma assinatura.",
			"es": "El mismo rastro en dos víctimas es una firma.",
			"ja": "二人の被害者に同じ痕跡があれば、それは署名だ。"
		},
		"lines": {
			"en": [
				[
					"Black dust on one patient's cuff. Hearth, road,",
					""
				],
				[
					"a careless hand: it proves nothing,",
					"and I will not"
				],
				[
					"accuse anyone on one mark.",
					"Then the second patient,"
				],
				[
					"who swears they never",
					"met the first, came in"
				],
				[
					"with the same dust",
					"on the same sleeve. Once is dirt."
				],
				[
					"Twice is",
					"a trade. Compare every garment."
				]
			],
			"pt_BR": [
				[
					"Pó escuro no punho de um paciente. Lareira, estrada,",
					""
				],
				[
					"uma mão descuidada: não prova nada,",
					"e não vou"
				],
				[
					"acusar ninguém por uma marca.",
					"Então o segundo paciente,"
				],
				[
					"que jura nunca ter",
					"encontrado o primeiro, chegou"
				],
				[
					"com o mesmo pó",
					"na mesma manga. Uma vez é sujeira."
				],
				[
					"Duas vezes",
					"é ofício. Compare todas as roupas."
				]
			],
			"es": [
				[
					"Polvo negro en el puño de un paciente. Hogar, camino,",
					""
				],
				[
					"una mano descuidada: no prueba nada,",
					"y no voy a"
				],
				[
					"acusar a nadie por una marca.",
					"Entonces el segundo paciente,"
				],
				[
					"que jura no haber",
					"conocido al primero, llegó"
				],
				[
					"con el mismo polvo",
					"en la misma manga. Una vez es suciedad."
				],
				[
					"Dos veces",
					"es un oficio. Compare cada prenda."
				]
			],
			"ja": [
				[
					"ある患者の袖口に黒い粉。炉か、道か、",
					""
				],
				[
					"不注意な手か。何の証明にもならないし、",
					"私は"
				],
				[
					"一つの痕で誰かを責めはしない。",
					"ところが二人目の患者が、"
				],
				[
					"最初の患者には",
					"会ったこともないと誓うのに、"
				],
				[
					"同じ粉を",
					"同じ袖につけてやって来た。一度なら汚れだ。"
				],
				[
					"二度なら",
					"それは職業だ。すべての衣服を比べよ。"
				]
			]
		}
	},
	{
		"id": 4,
		"lore": "fog",
		"layout": [
			[
				"A",
				"B"
			],
			[
				"A",
				"B"
			],
			[
				"A",
				"B"
			],
			[
				"A",
				"C"
			],
			[
				"A",
				"C"
			],
			[
				"A",
				"C"
			],
			[
				"A",
				"C"
			]
		],
		"places": {
			"B": [
				"Escola",
				"Biblioteca"
			],
			"C": [
				"Praca",
				"Prefeitura"
			]
		},
		"title": {
			"en": "The day of the fog",
			"pt_BR": "O dia da neblina",
			"es": "El día de la niebla",
			"ja": "霧の日"
		},
		"learned": {
			"en": "Fed, and under a grey sky, it can walk by day.",
			"pt_BR": "Alimentado, sob céu cinzento, ele pode andar de dia.",
			"es": "Alimentado, y bajo un cielo gris, puede andar de día.",
			"ja": "満ち足りて空が灰色なら、それは昼でも歩ける。"
		},
		"lines": {
			"en": [
				[
					"On clear mornings",
					"some doors stay shut,"
				],
				[
					"and their owners",
					"plead the same sickness."
				],
				[
					"I believed them.",
					"Then came the day of the fog,"
				],
				[
					"and I saw one",
					"of those sick ones in the square,"
				],
				[
					"walking easily,",
					"buying bread like anyone."
				],
				[
					"Fed, and under",
					"a grey sky, it needs no excuse."
				],
				[
					"Hungry, or in",
					"plain sun, it keeps to its bed."
				]
			],
			"pt_BR": [
				[
					"Nas manhãs de céu limpo,",
					"certas portas ficam fechadas,"
				],
				[
					"e os donos",
					"alegam a mesma doença."
				],
				[
					"Eu acreditei.",
					"Então veio o dia da neblina,"
				],
				[
					"e vi um",
					"daqueles doentes na praça,"
				],
				[
					"andando à vontade,",
					"comprando pão como qualquer um."
				],
				[
					"Alimentado, sob",
					"um céu cinzento, não precisa de desculpa."
				],
				[
					"Com fome, ou sob",
					"sol aberto, fica na cama."
				]
			],
			"es": [
				[
					"En las mañanas despejadas",
					"algunas puertas siguen cerradas,"
				],
				[
					"y sus dueños",
					"alegan la misma enfermedad."
				],
				[
					"Les creí.",
					"Entonces llegó el día de la niebla,"
				],
				[
					"y vi a uno",
					"de esos enfermos en la plaza,"
				],
				[
					"paseando tranquilo,",
					"comprando pan como cualquiera."
				],
				[
					"Alimentado, y bajo",
					"un cielo gris, no necesita excusa."
				],
				[
					"Con hambre, o bajo",
					"sol pleno, se queda en cama."
				]
			],
			"ja": [
				[
					"晴れた朝には",
					"閉じたままの戸がある。"
				],
				[
					"その家の者たちは",
					"皆同じ病を訴える。"
				],
				[
					"私は信じていた。",
					"だが霧の日が来て、"
				],
				[
					"私は見た。",
					"病人のはずの一人が広場で、"
				],
				[
					"楽々と歩き、",
					"皆と同じようにパンを買うのを。"
				],
				[
					"満ち足りて、",
					"空が灰色なら、言い訳は要らない。"
				],
				[
					"飢えているか、",
					"陽が照っていれば、床から出ない。"
				]
			]
		}
	},
	{
		"id": 5,
		"lore": "watch",
		"layout": [
			[
				"B",
				"A"
			],
			[
				"B",
				"A"
			],
			[
				"B",
				"A"
			],
			[
				"B",
				"C"
			],
			[
				"B",
				"C"
			],
			[
				"B",
				"C"
			],
			[
				"B",
				"C"
			]
		],
		"places": {
			"B": [
				"#house"
			],
			"C": [
				"Taverna",
				"Igreja"
			]
		},
		"title": {
			"en": "The door",
			"pt_BR": "A porta",
			"es": "La puerta",
			"ja": "戸"
		},
		"learned": {
			"en": "A watched door keeps it out.",
			"pt_BR": "Uma porta vigiada o mantém do lado de fora.",
			"es": "Una puerta vigilada lo mantiene fuera.",
			"ja": "見張られた戸は、それを中に入れない。"
		},
		"lines": {
			"en": [
				[
					"A patient swears",
					"something stood outside her door"
				],
				[
					"long after the house",
					"was quiet. No latch broken."
				],
				[
					"It did not come in.",
					"I called it a dream,"
				],
				[
					"until I learned she",
					"had been awake, watching the door."
				],
				[
					"A locked door",
					"does not stop it. A watched one does."
				],
				[
					"If someone wakes",
					"with a burning neck,"
				],
				[
					"sit outside",
					"their door that night. Until dawn."
				]
			],
			"pt_BR": [
				[
					"Uma paciente jura que algo",
					"ficou do lado de fora da porta"
				],
				[
					"muito depois de a casa",
					"silenciar. Nenhum trinco quebrado."
				],
				[
					"Não entrou.",
					"Chamei de sonho,"
				],
				[
					"até saber que ela",
					"estava acordada, vigiando a porta."
				],
				[
					"Uma porta trancada",
					"não o detém. Uma porta vigiada, sim."
				],
				[
					"Se alguém acordar",
					"com o pescoço ardendo,"
				],
				[
					"sente-se diante",
					"da porta dele naquela noite. Até o amanhecer."
				]
			],
			"es": [
				[
					"Una paciente jura que algo",
					"se quedó junto a su puerta"
				],
				[
					"mucho después de que la casa",
					"callara. Ningún pestillo roto."
				],
				[
					"No entró.",
					"Lo llamé un sueño,"
				],
				[
					"hasta saber que ella",
					"estaba despierta, vigilando la puerta."
				],
				[
					"Una puerta con llave",
					"no lo detiene. Una vigilada, sí."
				],
				[
					"Si alguien despierta",
					"con el cuello ardiendo,"
				],
				[
					"siéntese frente",
					"a su puerta esa noche. Hasta el alba."
				]
			],
			"ja": [
				[
					"ある患者は誓う。",
					"何かが戸の外に立っていたと。"
				],
				[
					"家が静まり返った",
					"ずっと後で。掛け金は壊れていない。"
				],
				[
					"それは入ってこなかった。",
					"私は夢だと言った。"
				],
				[
					"だが彼女は",
					"起きて、戸を見張っていたのだと知った。"
				],
				[
					"鍵のかかった戸では",
					"止まらない。見張られた戸なら止まる。"
				],
				[
					"首が焼けるように",
					"痛むと目覚めた者がいたら、"
				],
				[
					"その夜は",
					"その戸の前に座れ。夜明けまで。"
				]
			]
		}
	},
	{
		"id": 6,
		"lore": "church",
		"layout": [
			[
				"A",
				"A"
			],
			[
				"A",
				"A"
			],
			[
				"A",
				"B"
			],
			[
				"B",
				"C"
			],
			[
				"B",
				"C"
			],
			[
				"B",
				"C"
			],
			[
				"B",
				"C"
			]
		],
		"places": {
			"B": [
				"Igreja"
			],
			"C": [
				"#cemetery",
				"Biblioteca"
			]
		},
		"title": {
			"en": "Holy ground",
			"pt_BR": "Solo sagrado",
			"es": "Suelo sagrado",
			"ja": "聖なる地"
		},
		"learned": {
			"en": "It will not set foot in the church grounds.",
			"pt_BR": "Ele não pisa no terreno da igreja.",
			"es": "No pisa el terreno de la iglesia.",
			"ja": "それは教会の敷地に足を踏み入れない。"
		},
		"lines": {
			"en": [
				[
					"I walked a weak man to the church gate.",
					""
				],
				[
					"His breathing eased there. He would not go in,",
					""
				],
				[
					"and would not say why.",
					"The priest called it comfort."
				],
				[
					"Perhaps. But after sunset",
					"I saw a shadow"
				],
				[
					"stop short of the",
					"church grounds,"
				],
				[
					"though no wall stood in its way. It does not",
					"tread on holy ground."
				],
				[
					"If ever it follows",
					"you at night, run for the church."
				]
			],
			"pt_BR": [
				[
					"Levei um homem fraco até o portão da igreja.",
					""
				],
				[
					"A respiração dele se acalmou ali. Não quis entrar,",
					""
				],
				[
					"e não quis dizer por quê.",
					"O padre chamou de consolo."
				],
				[
					"Talvez. Mas depois do pôr do sol",
					"vi uma sombra"
				],
				[
					"parar antes do",
					"terreno da igreja,"
				],
				[
					"embora nenhum muro estivesse no caminho. Não",
					"pisa em solo sagrado."
				],
				[
					"Se um dia ela",
					"te seguir à noite, corra para a igreja."
				]
			],
			"es": [
				[
					"Acompañé a un hombre débil hasta la verja de la iglesia.",
					""
				],
				[
					"Allí su respiración se calmó. No quiso entrar,",
					""
				],
				[
					"ni quiso decir por qué.",
					"El cura lo llamó consuelo."
				],
				[
					"Quizá. Pero tras la puesta de sol",
					"vi una sombra"
				],
				[
					"detenerse antes del",
					"terreno de la iglesia,"
				],
				[
					"aunque ningún muro se lo impedía. No",
					"pisa suelo sagrado."
				],
				[
					"Si alguna vez te sigue",
					"de noche, corre a la iglesia."
				]
			],
			"ja": [
				[
					"弱った男を教会の門まで連れて行った。",
					""
				],
				[
					"そこで彼の息は落ち着いた。中へは入ろうとせず、",
					""
				],
				[
					"理由も言わなかった。",
					"神父は安らぎだと言った。"
				],
				[
					"そうかもしれない。だが日没後、",
					"私は影を見た。"
				],
				[
					"それが止まるのを、",
					"教会の敷地の手前で。"
				],
				[
					"行く手を阻む壁などないのに。それは",
					"聖なる地を踏まない。"
				],
				[
					"もし夜に",
					"それに追われたら、教会へ走れ。"
				]
			]
		}
	},
	{
		"id": 7,
		"lore": "river",
		"layout": [
			[
				"A",
				"B"
			],
			[
				"A",
				"B"
			],
			[
				"A",
				"B"
			],
			[
				"A",
				"B"
			],
			[
				"C",
				"B"
			],
			[
				"C",
				"B"
			],
			[
				"C",
				"C"
			]
		],
		"places": {
			"B": [
				"#bridge",
				"Prefeitura"
			],
			"C": [
				"#cemetery",
				"Biblioteca"
			]
		},
		"title": {
			"en": "The river",
			"pt_BR": "O rio",
			"es": "El río",
			"ja": "川"
		},
		"learned": {
			"en": "It cannot cross running water, not even by the bridge.",
			"pt_BR": "Ele não atravessa água corrente, nem pela ponte.",
			"es": "No puede cruzar agua corriente, ni siquiera por el puente.",
			"ja": "それは流れる水を渡れない。橋を使っても。"
		},
		"lines": {
			"en": [
				[
					"Footprints in the mud",
					"by the river, at night,"
				],
				[
					"pacing to the bridge",
					"and back. Again and again."
				],
				[
					"Never across.",
					"The river was high with rain."
				],
				[
					"Every attack this month",
					"on this side of the water;"
				],
				[
					"the graves beyond",
					"the bridge untouched."
				],
				[
					"Old women say it cannot",
					"cross running water alone."
				],
				[
					"A month ago I laughed at them.",
					""
				]
			],
			"pt_BR": [
				[
					"Pegadas na lama",
					"junto ao rio, à noite,"
				],
				[
					"indo até a ponte",
					"e voltando. De novo e de novo."
				],
				[
					"Nunca do outro lado.",
					"O rio estava cheio de chuva."
				],
				[
					"Todos os ataques deste mês",
					"deste lado da água;"
				],
				[
					"os túmulos além",
					"da ponte, intocados."
				],
				[
					"As velhas dizem que ele não",
					"atravessa água corrente sozinho."
				],
				[
					"Há um mês eu ri delas.",
					""
				]
			],
			"es": [
				[
					"Huellas en el barro",
					"junto al río, de noche,"
				],
				[
					"yendo hasta el puente",
					"y volviendo. Una y otra vez."
				],
				[
					"Nunca al otro lado.",
					"El río iba crecido por la lluvia."
				],
				[
					"Todos los ataques de este mes",
					"a este lado del agua;"
				],
				[
					"las tumbas más allá",
					"del puente, intactas."
				],
				[
					"Las viejas dicen que no puede",
					"cruzar agua corriente solo."
				],
				[
					"Hace un mes me reí de ellas.",
					""
				]
			],
			"ja": [
				[
					"泥の中の足跡。",
					"夜、川のほとり。"
				],
				[
					"橋まで行っては",
					"戻る。何度も、何度も。"
				],
				[
					"決して渡らない。",
					"川は雨で増水していた。"
				],
				[
					"今月の襲撃はすべて",
					"水のこちら側だ。"
				],
				[
					"橋の向こうの",
					"墓は手つかずのまま。"
				],
				[
					"老婆たちは言う、それは",
					"流れる水を一人では渡れないと。"
				],
				[
					"ひと月前、私は彼女たちを笑った。",
					""
				]
			]
		}
	},
	{
		"id": 8,
		"lore": "marked",
		"layout": [
			[
				"B",
				"A"
			],
			[
				"B",
				"A"
			],
			[
				"B",
				"A"
			],
			[
				"C",
				"A"
			],
			[
				"C",
				"A"
			],
			[
				"C",
				"A"
			],
			[
				"C",
				"A"
			]
		],
		"places": {
			"B": [
				"#house"
			],
			"C": [
				"Escola",
				"Taverna"
			]
		},
		"title": {
			"en": "The marked",
			"pt_BR": "Os marcados",
			"es": "Los marcados",
			"ja": "印をつけられた者"
		},
		"learned": {
			"en": "The marked are its own by the next night, unless given iron that same day.",
			"pt_BR": "Os marcados são dele na noite seguinte, a não ser que tomem ferro no mesmo dia.",
			"es": "Los marcados son suyos a la noche siguiente, salvo que tomen hierro ese mismo día.",
			"ja": "印をつけられた者は、その日のうちに鉄剤を与えなければ、次の夜にはそれのものになる。"
		},
		"lines": {
			"en": [
				[
					"Some wake with no",
					"blood lost, no pale lips,"
				],
				[
					"only a burning at",
					"the neck and a dread"
				],
				[
					"they cannot name.",
					"I used to send them home."
				],
				[
					"It does not keep all",
					"it feeds on. The ones"
				],
				[
					"it marks, it means",
					"to keep: by the next night"
				],
				[
					"they are its own,",
					"and cannot say its name."
				],
				[
					"Iron the same day.",
					"Tomorrow is too late. I waited once."
				]
			],
			"pt_BR": [
				[
					"Alguns acordam sem perder",
					"sangue, sem lábios pálidos,"
				],
				[
					"só com um ardor",
					"no pescoço e um medo"
				],
				[
					"que não sabem nomear.",
					"Eu os mandava para casa."
				],
				[
					"Ele não guarda todos",
					"de quem se alimenta. Os que"
				],
				[
					"marca, quer",
					"para si: na noite seguinte"
				],
				[
					"já são dele,",
					"e não conseguem dizer seu nome."
				],
				[
					"Ferro no mesmo dia.",
					"Amanhã é tarde demais. Esperei uma vez."
				]
			],
			"es": [
				[
					"Algunos despiertan sin perder",
					"sangre, sin labios pálidos,"
				],
				[
					"solo con un ardor",
					"en el cuello y un miedo"
				],
				[
					"que no saben nombrar.",
					"Yo los mandaba a casa."
				],
				[
					"No se queda con todos",
					"de los que se alimenta. A los que"
				],
				[
					"marca, los quiere",
					"para sí: a la noche siguiente"
				],
				[
					"ya son suyos,",
					"y no pueden decir su nombre."
				],
				[
					"Hierro el mismo día.",
					"Mañana es tarde. Yo esperé una vez."
				]
			],
			"ja": [
				[
					"血を失わず、",
					"唇も青ざめずに目覚める者がいる。"
				],
				[
					"あるのは",
					"首の焼けるような痛みと、"
				],
				[
					"名づけようのない恐怖だけ。",
					"私は彼らを家に帰していた。"
				],
				[
					"それは糧にした者を",
					"皆手元に置くわけではない。"
				],
				[
					"印をつけた者は、",
					"手元に置くつもりだ。次の夜には"
				],
				[
					"もうそれのものとなり、",
					"その名を口にできない。"
				],
				[
					"その日のうちに鉄剤を。",
					"明日では遅い。私は一度待ってしまった。"
				]
			]
		}
	},
	{
		"id": 9,
		"whole": true,
		"hidden": true,
		"text": {
			"en": "I have reduced seven lives to seven suspicions,\nand seven suspicions to one name: {name}.\nIt may be the right one. It may be only the name\nI can bear to write. The fog has thickened over the square.\nMy lamp is trimmed, and the bell has not yet struck twelve.\nI shall sit outside that door tonight and watch until dawn.\nIf you are reading this, I was wrong about something.\n\n— E. H.",
			"pt_BR": "Reduzi sete vidas a sete suspeitas,\ne sete suspeitas a um nome: {name}.\nPode ser o certo. Pode ser só o nome\nque consigo suportar escrever. A neblina engrossou sobre a praça.\nA lamparina está pronta, e o sino ainda não bateu meia-noite.\nVou me sentar diante daquela porta esta noite e vigiar até o amanhecer.\nSe você está lendo isto, eu me enganei sobre alguma coisa.\n\n— E. H.",
			"es": "He reducido siete vidas a siete sospechas,\ny siete sospechas a un nombre: {name}.\nPuede que sea el correcto. Puede que sea solo el nombre\nque soporto escribir. La niebla se ha espesado sobre la plaza.\nMi lámpara está lista, y la campana aún no ha dado las doce.\nEsta noche me sentaré frente a esa puerta y vigilaré hasta el alba.\nSi estás leyendo esto, me equivoqué en algo.\n\n— E. H.",
			"ja": "七つの命を七つの疑いに、\n七つの疑いを一つの名に絞った。{name}。\n正しい名かもしれない。書くことに耐えられる\n名にすぎないのかもしれない。広場の霧が濃くなった。\nランプの芯は整えた。鐘はまだ十二時を打っていない。\n今夜はあの戸の外に座り、夜明けまで見張るつもりだ。\nこれを読んでいるなら、私は何かを間違えたのだ。\n\n— E. H."
		},
		"places": {
			"W": [
				"#cemetery"
			]
		},
		"title": {
			"en": "The last page",
			"pt_BR": "A última página",
			"es": "La última página",
			"ja": "最後の頁"
		}
	}
]
