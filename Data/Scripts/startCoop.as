array<int> playerIds;
int mainCharacterID;
bool mainCharacterIDFound;
array<string> characterModels;

void Init(string levelName) {
    //Log(info, "(full-local-coop) # of players: " + GetConfigValueInt("players"));
    if (GetConfigValueInt("players") == 0) SetConfigValueInt("players", 2);  // Default 2 players
    mainCharacterIDFound = false;
    playerIds = {};
    characterModels = {"male_rabbit_3", "female_rabbit_1", "pale_rabbit_civ"};
}

// Find mainObject character to use as baseline when spawning other players
void Update() {
    // If the players haven't been spawned yet, 
    if (!mainCharacterIDFound) {
        // Find the mainObject character (to use as a baseline for the other players)
        int characters = GetNumCharacters();
        for (int i = 0; i < characters; i++) {
            MovementObject@ char = ReadCharacter(i);
            if (char.controlled) {
                mainCharacterIDFound = true;

                mainCharacterID = char.GetID();
                playerIds.insertLast(mainCharacterID);
                SpawnPlayers();
                break;
            }
        }
    } else if (GetInputPressed(0, "F9")) {
        int currentAmount = GetConfigValueInt("players");
        // Max players is 4
        if (currentAmount == 4) return;
        currentAmount++;
        SetConfigValueInt("players", currentAmount);
        SpawnPlayers();
    } else if (GetInputPressed(0, "F10")) {
        int currentAmount = GetConfigValueInt("players");
        // Min players is 1
        if (GetConfigValueInt("players") == 1) return;
        currentAmount--;
        SetConfigValueInt("players", currentAmount);
        SpawnPlayers();
    }
}


void SpawnPlayers() {
    int desiredPlayers = GetConfigValueInt("players");
    int currentPlayers = playerIds.length();
    // Too little players
    if (currentPlayers < desiredPlayers) SpawnPlayer(desiredPlayers);
    // Too many players
    else if (currentPlayers > desiredPlayers) DespawnPlayer(desiredPlayers);
}

void SpawnPlayer(int desiredPlayers) {
    int newCharacter = NewCharacter(characterModels[playerIds.length()-1], 1, 1);
    playerIds.insertLast(newCharacter);
    int currentPlayers = playerIds.length();
    if (currentPlayers < desiredPlayers) SpawnPlayer(desiredPlayers);
}

void DespawnPlayer(int desiredPlayers) {
    int removedCharacterID = playerIds[playerIds.length() - 1];

    // Prevent bugs after removing character
    int characters = GetNumCharacters();
    for (int i = 0; i < characters; i++) {
        MovementObject@ character = ReadCharacter(i);
        character.Execute("MovementObjectDeleted(" + removedCharacterID + ");");
    }
    
    QueueDeleteObjectID(removedCharacterID);
    playerIds.removeLast();

    characters = GetNumCharacters();
    for (int i = 0; i < characters; i++) {
        MovementObject@ character = ReadCharacter(i);
        character.Execute("MovementObjectDeleted(" + removedCharacterID + ");");
    }

    int currentPlayers = playerIds.length();
    if (currentPlayers > desiredPlayers) DespawnPlayer(desiredPlayers);
}

int NewCharacter(string riggedObject, int xModifier, int yModifier) {
    Object@ mainObject = ReadObjectFromID(mainCharacterID);
    MovementObject@ mainCharacter = ReadCharacterID(mainCharacterID);
    MovementObject@ newCharacter = ReadCharacterID(DuplicateObject(mainObject));
    // Improve the spawnpoint (spawning on top of another character causes instability)
    // Set position to mainObject (first player)
    newCharacter.position = mainCharacter.position;
    // Move slightly
    newCharacter.position.x = newCharacter.position.x + xModifier;
    newCharacter.position.y = newCharacter.position.y + yModifier;
    // Create rigged object
    // Use raider rabbit as default if none other is specified
    if (riggedObject.isEmpty()) riggedObject = "Data/Characters/raider_rabbit.xml";
    // Else use the specified model
    // if '/' is not in the title (and thus the title isn't a path), append the default location/type
    else if (riggedObject.findFirst("/") < 0) riggedObject = "Data/Characters/" + riggedObject + ".xml";
    
   
    newCharacter.Execute("this_mo.RecreateRiggedObject(\"" + riggedObject + "\");");
    // Params go from 0.0 -> 1.0 (1.0 is then 200)
    //newCharacter.Execute("p_muscle = 1;");
    //newCharacter.Execute("ApplyBoneInflation();");
    
    if (mainCharacter.GetBoolVar("g_wearing_metal_armor") == true) {
        // For some reason, bools have to be passed in capitals
        newCharacter.Execute("g_wearing_metal_armor = TRUE;");
    }

    array<int> weapons = GetObjectIDsType(32);
    if (weapons.length() > 0) {
        int newWeaponId = DuplicateObject(ReadObjectFromID(weapons[0]));
        newCharacter.Execute("AttachWeapon(" + newWeaponId + ");");
    }

    return newCharacter.GetID();
}
