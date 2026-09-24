import math,random,wave,struct
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/"assets"/"audio"
OUT.mkdir(parents=True,exist_ok=True)
sr=22050
rng=random.Random(307)
for name,duration in [('siren',2.0),('crowd',4.0),('defeat',0.9)]:
 data=[]; smooth=0.0
 for i in range(int(sr*duration)):
  t=i/sr
  if name=='siren':
   phase=2*math.pi*700*t+180*math.sin(2*math.pi*t)
   value=.22*math.sin(phase)+.06*math.sin(phase*2)
  elif name=='defeat':
   freq=[220,174.61,130.81][min(2,int(t/.3))]
   env=math.exp(-((t%.3)*12))
   value=(.22*math.sin(2*math.pi*freq*t)+.07*math.sin(2*math.pi*freq*2*t))*env
  else:
   smooth=.75*smooth+.25*rng.uniform(-1,1)
   cheer=.07*math.sin(2*math.pi*440*t+6*math.sin(t*6))*(.5+.5*math.sin(t*3))
   clap=(rng.uniform(-1,1)*.32*math.exp(-((t*7)%1)*18))
   value=smooth*.55+cheer+clap
  edge=min(1,t/.015,(duration-t)/.015)
  data.append(struct.pack('<h',int(max(-1,min(1,value*edge))*32767)))
 with wave.open(str(OUT/(name+'.wav')),'wb') as f:
  f.setparams((1,2,sr,0,'NONE','not compressed'));f.writeframes(b''.join(data))
