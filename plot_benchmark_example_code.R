library(dplyr)
library(tidyverse)
library(ggplot2)
library(stringr)
library(cowplot)
# library(GGally)

file1='/awesome/elly/tmp/subfile5benchmark.txt'

taskdata=read.delim(file1)

taskdata = taskdata %>% mutate(thread=factor(thread))

# remove runs with mistake
t1=taskdata %>% filter(task=='f5c_rx_eventalign')
t2=taskdata %>% filter(task!='f5c_rx_eventalign')
t1a=t1 %>% filter(set!='fc')
taskdata = bind_rows(t2, t1a)

# colnames(taskdata)
# unique(taskdata$task)

# https://www.datanovia.com/en/blog/how-to-plot-one-variable-against-multiple-others/
snakebenchlist=c("s","max_rss","max_vms","max_uss","max_pss","io_in","io_out","mean_load","cpu_time")
customlist=c('thread', 'sample', 'task', 'set', 'rep')


plotdata=taskdata %>%
  select(all_of(snakebenchlist), all_of(customlist)) %>%
  as.data.frame() %>%
  gather(key = "variable", value = "value",
         -all_of(customlist))

imgodir='/awesome/elly/tmp/'
subtitle1='8x replicates per thread, using input data of 5x subfiles'
for (task1 in unique(taskdata$task)) {
  message('> ',task1)
  p1=plotdata %>% filter(task==task1) %>%
    ggplot(aes(x=thread, y=value, fill=sample)) +
    geom_boxplot() +
    facet_wrap(~variable, scales = 'free_y') +
    labs(title=sprintf("%s - snakemake benchmark",task1), subtitle=subtitle1)
  ofile=file.path(imgodir, sprintf('subfile5test_%s.png', task1))
  ggsave(
    filename = ofile, plot = p1, device = 'png',
    width=1900, height=1200, dpi=150, units='px'
  )
  rm(p1)
}


taskdata %>% filter(task=='nanopolish_eventalign' | task=='f5c_eventalign' | task=='f5c_rx_eventalign') %>%
  ggplot(aes(x=thread, y=s, fill=sample)) +
  geom_boxplot() +
  facet_wrap(~task)
