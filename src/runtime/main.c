/**
 * main.c
 * @copyright (c) 2007-2009, Tohoku University.
 * @author UENO Katsuhiro
 */

#include "smlsharp.h"

void sml_main(void);
void sml_load(void *);

int
main(int argc, char **argv)
{
	sml_init(argc, argv);
	sml_gcroot_load(&(void(*)(void *)){sml_load}, 1);
	sml_main();
	sml_exit(0);
}
