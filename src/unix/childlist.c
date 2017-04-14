
#include "processx-unix.h"

processx__child_list_t child_list_head = { 0, 0, 0 };
processx__child_list_t *child_list = &child_list_head;
processx__child_list_t child_free_list_head = { 0, 0, 0 };
processx__child_list_t *child_free_list = &child_free_list_head;

void processx__freelist_add(processx__child_list_t *ptr) {
  ptr->next = child_free_list->next;
  child_free_list->next = ptr;
}

void processx__freelist_free() {
  processx__child_list_t *ptr = child_free_list->next;
  while (ptr) {
    processx__child_list_t *next = ptr->next;
    free(ptr);
    ptr = next;
  }
  child_free_list->next = 0;
}

int processx__child_add(pid_t pid, SEXP status) {
  processx__child_list_t *child = calloc(1, sizeof(processx__child_list_t));
  if (!child) return 1;
  child->pid = pid;
  child->status = status;
  child->next = child_list->next;
  child_list->next = child;
  return 0;
}

void processx__child_remove(pid_t pid) {
  processx__child_list_t *prev = child_list, *ptr = child_list->next;
  while (ptr) {
    if (ptr->pid == pid) {
      prev->next = ptr->next;
      memset(ptr, 0, sizeof(*ptr));
      /* Defer freeing the memory, because malloc/free are typically not
	 reentrant, and if we free in the SIGCHLD handler, that can cause
	 crashes. The test case in test-run.R (see comments there)
	 typically brings this out. */
      processx__freelist_add(ptr);
    }
    prev = ptr;
    ptr = ptr->next;
  }
}

processx__child_list_t *processx__child_find(pid_t pid) {
  processx__child_list_t *ptr = child_list->next;
  while (ptr) {
    if (ptr->pid == pid) return ptr;
    ptr = ptr->next;
  }
  return 0;
}
