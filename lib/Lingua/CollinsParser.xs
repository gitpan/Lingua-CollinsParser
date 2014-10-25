#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

/* Standard system headers: */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>

/* Stuff from the Collins parser source: */
#include "lexicon.h"
#include "grammar.h"
#include "mymalloc.h"
#include "mymalloc_char.h"
#include "hash.h"
#include "prob.h"
#include "readevents.h"
#include "sentence.h"
#include "chart.h"


#ifndef PERL_UNUSED_VAR
#define PERL_UNUSED_VAR(var) if (0) var = var
#endif

sentence_type sentences[2500];

AV *unpack_aref(SV *input_rv) {
  if ( !SvROK(input_rv) || SvTYPE(SvRV(input_rv)) != SVt_PVAV ) {
    croak("Argument must be array reference");
  }
  
  return (AV*) SvRV(input_rv);
}

char *node_types[4] = { "leaf", "nonterminal", "", "unary" };

/* (TOP~flies~1~1 (S~flies~2~2 (NPB~bird~2~2 The/DT bird/NN ) (VP~flies~1~1 flies/VBZ ) ) ) */
SV* edge_as_tree(int e) {
  int i,j,w,next;
  int flag;
  AV *children;
  HV *output, *node_stash;
  edge_type edge;

  sentence_type *current = get_current();
  edge_type *edges = chart_edges();
  int *childs = chart_childs();
  
  if(e==-1)
    return sv_newmortal(); /* returns undef */

  edge = edges[e];

  flag=1;
  
  if(get_treebankoutputflag() &&
   (edge.label == NT_NP || edge.label == NT_NPA)
     && edge.numchild ==1)
    {
      j= childs[edge.child1];
      if(edges[j].label == NT_NPB)
	flag=0;
    }

  output = newHV();
  hv_store(output, "node_type", 9, newSVpv(node_types[(int) edge.type], 0), 0);

  /* We're going to bless the output into this class (should probably
   * call ->new(...), though)
   */

  node_stash = gv_stashpv("Lingua::CollinsParser::Node", 0);

  /*POS tag case*/

  /*POS tag - print preceding punctuation*/
  /* All the printf() stuff in here is code that needs to be converted to perl */
  if(edge.type==0)
    {
      SV *token, *pos;

      if(edge.head==0)
	for(i=0;i<current->wordpos[0];i++)
	  printf("%s/PUNC%s ",current->words[i],current->tags[i]);

      token = newSVpv( current->words[current->wordpos[edge.head]], 0 );
      hv_store(output, "token", 5, token, 0);

      pos = newSVpv( nts[(int) edge.headtag], 0 );
      hv_store(output, "label", 5, pos, 0);

      w=current->wordpos[edge.head];
      if(edge.head==current->nws_np-1)
	next=current->nws;
      else
	next=current->wordpos[edge.head+1];
      for(i=w+1;i<next;i++)
	printf("%s/PUNC%s ",current->words[i],current->tags[i]);
      
      return sv_bless(newRV_noinc((SV*) output), node_stash);
    }

  if(flag)
    {
      /* printf("%s",nts[(int) edge.label]); */
      SV *label = newSVpv( nts[(int) edge.label], 0 );
      hv_store(output, "label", 5, label, 0);

      
      if(1) {/* the print_wholent() code */
	if(edge.type==4)
	  {
	    printf("_NA~%d",edge.numchild);
	  }
	else
	  {
	    SV *head = newSVpv( current->words[current->wordpos[edge.head]], 0 );
	    hv_store(output, "head_token", 10, head, 0);
	    hv_store(output, "num_children", 12, newSViv(edge.numchild), 0);
	    hv_store(output, "head_child", 10, newSViv(find_childno(e,edge.headch)-1), 0);
	  }
      }
    }

  children = newAV();
  
  for(i=edge.child1; i<edge.child1+edge.numchild; i++)
    {
      av_push(children, edge_as_tree(childs[i]));
    }
  
  hv_store(output, "children", 8, newRV_noinc((SV*) children), 0);
  
  return sv_bless(newRV_noinc((SV*) output), node_stash);
}


MODULE = Lingua::CollinsParser         PACKAGE = Lingua::CollinsParser

PROTOTYPES: DISABLE

void
set_beamsize (beamsize)
     double beamsize
    CODE:
      BEAMPROB = log((float) beamsize);

void
set_punc_flag (punc_flag)
     int punc_flag
    CODE:
      PUNC_FLAG = punc_flag;

void
set_distaflag (flag)
     int flag;
    CODE:
      DISTAFLAG = flag;

void
set_distvflag (flag)
     int flag;
    CODE:
      DISTVFLAG = flag;

void
set_npflag (flag)
     int flag;
    CODE:
      if (flag != 0 && flag != 1)
        croak("flag value must be 0 or 1, not %d", flag);
      set_treebankoutputflag(flag);


double
get_beamsize ()
    CODE:
      RETVAL = (double) exp(BEAMPROB);
    OUTPUT:
      RETVAL

int
get_punc_flag ()
    CODE:
      RETVAL = PUNC_FLAG;
    OUTPUT:
      RETVAL

int
get_distaflag ()
    CODE:
      RETVAL = DISTAFLAG;
    OUTPUT:
      RETVAL

int
get_distvflag ()
    CODE:
      RETVAL = DISTVFLAG;
    OUTPUT:
      RETVAL

int
get_npflag ()
    CODE:
      RETVAL = get_treebankoutputflag();
    OUTPUT:
      RETVAL

void
_xs_init (self)
    SV   * self
  CODE:
    {
      PERL_UNUSED_VAR(self);
      mymalloc_init();
      mymalloc_char_init();
    }

int
load_events (self, events_file)
    SV   * self
    char * events_file
  CODE:
    {
      FILE *events = fopen(events_file,"r");
      PERL_UNUSED_VAR(self);
      if (events == NULL)
	croak("Can't read %s: %s", events_file, strerror(errno));
      
      hash_make_table(8000007,&new_hash);
      read_events(events,&new_hash,-1);
      RETVAL = 1;
    }
  OUTPUT:
    RETVAL
      

int
load_grammar (self, grammar_file)
    SV   * self
    char * grammar_file
  CODE:
    {
      PERL_UNUSED_VAR(self);
      effhash_make_table(1000003,&eff_hash);
      read_grammar(grammar_file);
      RETVAL = 1;
    }
  OUTPUT:
    RETVAL

void
parse_sentence (self, words_in, tags_in)
    SV    *self
    SV    *words_in
    SV    *tags_in
  PPCODE:
    {
      int i, j, best, numwords;
      sentence_type *s;
      SV *output, **fetched;
      AV *words, *tags;
      PERL_UNUSED_VAR(self);

      words = unpack_aref(words_in);
      tags = unpack_aref(tags_in);

      numwords = av_len(words)+1;
      if (numwords >= PMAXWORDS)
	croak("Too many words given, maximum is %d", PMAXWORDS);
      if (numwords != av_len(tags)+1)
	croak("%d words given, but %d tags given", numwords, av_len(tags)+1);

      /* Fill the sentence_type struct */
      s = (sentence_type *) malloc(sizeof(sentence_type));
      s->nws = numwords;
      for (i=0; i<numwords; i++) {
	fetched = av_fetch(words, i, 0);
	if (fetched == NULL)
	  croak("Word %d was missing unexpectedly", i);
	s->words[i] = SvPV_nolen(*fetched);

	fetched = av_fetch(tags, i, 0);
	if (fetched == NULL)
	  croak("Tag %d was missing unexpectedly", i);
	s->tags[i] = SvPV_nolen(*fetched);
      }
      convert_sentence(s);
      
      /* Parse the sentence */
      pthresh = -5000000;
      reset_prior_hashprobs();
      effhash_newsent(&eff_hash);
      init_chart(GMAXNTS);
      set_current(s);
      
      add_sentence_to_chart(s);
      
      for(i=0;i<s->nws_np;i++)
	for(j=i-1;j>=0;j--)
	  {
	    complete(j,i);
	  }
      
      /* See if there was a decent parse - if not, return an empty
	 list (or the undef value) */
      best = best_parse();
      if (best == -1) {
	if (GIMME_V == G_SCALAR) XSRETURN_UNDEF;
	XSRETURN_EMPTY;
      }
      
      /*       printf("PROB %d %g %d \n", best, edges[best].prob, edges[best].stop); */
      /*       print_edge(best, 0); */
      /* print_edges_flat(best); */
      output = edge_as_tree(best);
      XPUSHs(sv_2mortal(output));
    }

void dump_events_hash (self, file)
    SV    *self
    char  *file
  PPCODE:
    {
      PERL_UNUSED_VAR(self);
      hash_dump(&new_hash, file);
    }

void undump_events_hash (self, file)
    SV    *self
    char  *file
  PPCODE:
    {
      hash_table *my_hash;
      PERL_UNUSED_VAR(self);
      hash_undump(&my_hash, file);
      new_hash.num = my_hash->num;
      new_hash.size = my_hash->size;
      new_hash.table = my_hash->table;
    }
