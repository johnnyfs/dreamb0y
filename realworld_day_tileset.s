*=$0000

include res/realworld_day_uniques.chr.s

*=$1000

include res/status_bar_uniques.chr.s
widget_chrs=((* - $1000) / 16) + 1
include res/widgets_sprites.chr.s
player_chrs=((* - $1000) / 16) + 1
include res/dreamboy_realworld_day_sprites.chr.s
