#ifndef __DEBUG_H_
#define __DEBUG_H_

// Modified to return string literals with correct address space
__constant char* item_to_string(item i) {
    switch(i) {
        case RETRY: return "RETRY";
        case J_BEGIN: return "J BEGIN";
        case J_C_BEGIN: return "J C BEGIN";
        case Joker: return "Joker";
        case Greedy_Joker: return "Greedy Joker";
        case Lusty_Joker: return "Lusty Joker";
        case Wrathful_Joker: return "Wrathful Joker";
        case Gluttonous_Joker: return "Gluttonous Joker";
        case Jolly_Joker: return "Jolly Joker";
        case Zany_Joker: return "Zany Joker";
        case Mad_Joker: return "Mad Joker";
        case Crazy_Joker: return "Crazy Joker";
        case Droll_Joker: return "Droll Joker";
        case Sly_Joker: return "Sly Joker";
        case Wily_Joker: return "Wily Joker";
        case Clever_Joker: return "Clever Joker";
        case Devious_Joker: return "Devious Joker";
        case Crafty_Joker: return "Crafty Joker";
        case Half_Joker: return "Half Joker";
        case Credit_Card: return "Credit Card";
        case Banner: return "Banner";
        case Mystic_Summit: return "Mystic Summit";
        case _8_Ball: return "8 Ball";
        case Misprint: return "Misprint";
        case Raised_Fist: return "Raised Fist";
        case Chaos_the_Clown: return "Chaos the Clown";
        case Scary_Face: return "Scary Face";
        case Abstract_Joker: return "Abstract Joker";
        case Delayed_Gratification: return "Delayed Gratification";
        case Gros_Michel: return "Gros Michel";
        case Even_Steven: return "Even Steven";
        case Odd_Todd: return "Odd Todd";
        case Scholar: return "Scholar";
        case Business_Card: return "Business Card";
        case Supernova: return "Supernova";
        case Ride_the_Bus: return "Ride the Bus";
        case Egg: return "Egg";
        case Runner: return "Runner";
        case Ice_Cream: return "Ice Cream";
        case Splash: return "Splash";
        case Blue_Joker: return "Blue Joker";
        case Faceless_Joker: return "Faceless Joker";
        case Green_Joker: return "Green Joker";
        case Superposition: return "Superposition";
        case To_Do_List: return "To Do List";
        case Cavendish: return "Cavendish";
        case Red_Card: return "Red Card";
        case Square_Joker: return "Square Joker";
        case Riff_raff: return "Riff raff";
        case Photograph: return "Photograph";
        case Mail_In_Rebate: return "Mail-In Rebate";
        case Hallucination: return "Hallucination";
        case Fortune_Teller: return "Fortune Teller";
        case Juggler: return "Juggler";
        case Drunkard: return "Drunkard";
        case Golden_Joker: return "Golden Joker";
        case Popcorn: return "Popcorn";
        case Walkie_Talkie: return "Walkie Talkie";
        case Smiley_Face: return "Smiley Face";
        case Golden_Ticket: return "Golden Ticket";
        case Swashbuckler: return "Swashbuckler";
        case Hanging_Chad: return "Hanging Chad";
        case Shoot_the_Moon: return "Shoot the Moon";
        // ... continue with all remaining cases ...
        default: return "Unknown Item";
    }
}

// Keep the original print_item function for backward compatibility
void print_item(item i) {
    printf("%s", item_to_string(i));
}

#endif