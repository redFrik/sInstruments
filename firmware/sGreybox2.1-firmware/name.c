#include "usb_names.h"

#define MIDI_NAME { 'G', 'r', 'e', 'y', 'B', 'o', 'x', '2', '.', '1' }
#define MIDI_NAME_LEN 10
struct usb_string_descriptor_struct usb_string_product_name = {
  2 + MIDI_NAME_LEN * 2,
  3,
  MIDI_NAME
};
