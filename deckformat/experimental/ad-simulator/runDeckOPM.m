function [wellsols,states,reports,extra] = runDeckOPM(deckfile,varargin)
%mrstModule add ad-blackoil ad-core mrst-gui ad-props deckformat
opt=struct('outputdir','output',...
    'simulator','flow',...
    'force_timestep',true,...
    'read_states',true,...
    'use_ebos_style',false,...
    'do_adjoint',false,...
    'no_output',false,...
    'verbose',true);
opt=merge_options(opt,varargin{:});
% for extra see .XXX.DEBUG of an opm run
if(opt.use_ebos_style)
    command=[opt.simulator,' --ecl-deck-file-name=',deckfile];
    [dir,case_name,ext]=fileparts(deckfile);
    opt.output=fullfile(dir);
else
    if(opt.force_timestep)
        command=[opt.simulator,'  --full-time-step-initially=true --enable-adaptive-time-stepping=false --flow-newton-max-iterations=100 '];
    else
        command=[opt.simulator,' --use-tuning=true --flow-newton-max-iterations=100 '];
    end
    if(opt.do_adjoint)
       % needed for adjoint
       command = [command,' --solve-welleq-initially=true --use-adjoint=true'];
       command = [command,' --matrix-add-well-contributions=true --preconditioner-add-well-contributions=true '];
       % adjust tolerances
       command = [command,...
			 ' --flow-linear-solver-verbosity=10  --linear-solver-max-iter=50 ',...
			 '--linear-solver-reduction=1e-10 ',... 
			  '--time-step-verbosity=10 ',...
                          '--tolerance-cnv=1e-6 ',...                        
			  '--tolerance-cnv-relaxed=1e-5 ',...                                                                    
			  '--tolerance-mb=1e-5 ',...                         
			  '--tolerance-pressure-ms-wells=1000 ',...
		          '--tolerance-well-control=1e-7 ',...
			 '--tolerance-wells=1e-4 '];
        % linear sovler
        command=[command,'--use-umfpack=true ']
        %command=[command,'--use-amgcl=true --use-amgcl-drs=true ']
        %command=[command,'--use-amg=true -use-cpr=true -use-gmres=true ']
    else
      if(opt.verbose)
        command = [command,'--linear-solver-verbose=1e-10 ']
      end
    end
    command = [command,'--output-dir=',opt.outputdir,' ',deckfile];
end
if(opt.no_output)
    command = [command,' >& /dev/null'];
end
delete(fullfile(opt.outputdir,'adjoint_results.txt'))
disp('MRST runing flow')
disp(command)
a = system(command)
if(a~=0)
    error('funning flow failed')
end
%% make normal output
if(nargout>0)
    opmdir=fullfile(opt.outputdir);
    [dir,case_name,ext]=fileparts(deckfile);
    ofile=fullfile(opmdir,case_name); 
    %opm_smry = readEclipseSummaryUnFmt(ofile);
    [wellsols_smry, time_smry]  = convertSummaryToWellSols(ofile,'metric');
    ofile_cap=fullfile(opmdir,upper(case_name));
    casenm=fullfile(opt.outputdir,upper(case_name));
    if(opt.read_states)
        init = readEclipseOutputFileUnFmt([casenm,'.INIT']);
        grid = readEclipseOutputFileUnFmt([casenm,'.EGRID']);    
        [G, rock, N, T] = eclOut2mrst(init, grid);
        extra=struct('G',G,'rock',rock,'N',N,'T',T,'init',init,'grid',grid);
        [states_opm,rstrt_opm] = convertRestartToStates(ofile_cap,G,...
        'use_opm',true,'includeWellSols',true,'wellSolsFromRestart',true,...
        'includeFluxes',true,'consistentWellSols',false);
    else
        states_opm=[];
        extra=[];
    end
    wellsols=wellsols_smry;
    if(opt.do_adjoint)
       adfile = fullfile(opmdir,'adjoint_results.txt');
       fn=fopen(adfile);
       wnames=fgetl(fn);
       wnames=fgetl(fn);
       fclose(fn);
       wnames=split(wnames(1:end));
       wnames={wnames{2:end-1}};
       admat=load(adfile);
       step = admat(1:3:end,1)+1;
       %  BHP, THP, RESERVOIR_RATE SURFACE_RATE and + 
       % 0,10,20 for water,oil gas ordering is MRST style of some
       % reason....
       ctrl_type = admat(1:3:end,2:end);%index + 10*(dist>0.5) NB hack
       objv = admat(2:3:end,2:end);
       derv = admat(3:3:end,2:end);
       derv_ctrl = zeros(max(step),size(objv,2));
       objvr= zeros(1,max(step));
       % sum derivative the setps not control : control is a MRST consept
       % ??
       
       for i=1:size(derv,1)
           derv_ctrl(step(i),:) = derv_ctrl(step(i),:) + derv(i,:);
           objvr(step(i)) = objvr(step(i)) + sum(objv(i,:),2);
       end
       adjoint=struct('wnames',{wnames},'obj',objvr,'derv',derv_ctrl,'ctrl_type',ctrl_type,...
           'objw',objv,'step',step,'dervall',derv,'objall',sum(objv,2));
    else
       adjoint=[];
    end
    
    reports=struct('ReservoirTime',time_smry,'adjoint',adjoint);
    states=states_opm;
end
