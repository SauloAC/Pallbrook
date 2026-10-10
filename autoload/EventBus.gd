extends Node

# Global signals: any system can emit or listen to these
signal phase_changed(is_night: bool)
signal npc_died(npc_name: String)
signal clue_found(clue_id: String)
signal player_collapsed
signal player_slept
signal hour_changed(hour: int)
signal dialogue_started(speaker: String, text: String)
signal dialogue_ended
