extends Node

enum GameMode {
	PVP,
	PVE
}

enum StartingChoice {
	GO_FIRST,
	RANDOM,
	GO_SECOND
}

var game_mode: GameMode = GameMode.PVP
var starting_choice: StartingChoice = StartingChoice.RANDOM
