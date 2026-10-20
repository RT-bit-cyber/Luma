#ifndef AMBIENT_HARDWARE_H
#define AMBIENT_HARDWARE_H
// Negative means unavailable, never darkness. The sensor API is private.
double ambient_read_lux(void);
void ambient_reset(void);
int ambient_lid_closed(void);
#endif
