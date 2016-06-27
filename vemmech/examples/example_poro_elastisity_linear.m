%{
This example set up a poro elastic problem which mimic a slize of of
overburden, with a infinite horizontal well in god aquifer at the bottum of
the domain. The poro elastic equation is put together explicitely an the
time loop is exposed. At the end we simulate the same case by using poro
elastic solvers.
%}
%{
Copyright 2009-2014 SINTEF ICT, Applied Mathematics
%}
% more examples can be generated by squareTest.m, see also
% overburde_2d_example which uses this tests
%% Define parameters
opt=struct('L',[10000 2000],...
    'cartDims',[20 20]*1,...
    'grid_type','square',...
    'disturb',0.0,... %parameter for disturbing grid
    'E',1e9,...  %youngs modolo
    'nu',0.2);% poiso ratio

%% define Grid
G=cartGrid(opt.cartDims,opt.L);
if(opt.disturb>0)
    G=twister(G,opt.disturb);
end
G=computeGeometry(G);

% gennerate extra mappings needed
G=mrstGridWithFullMappings(G);
% generate weights needed
G=computeGeometryCalc(G);
figure()
clf,plotGrid(G)
%% Find sides of domain
% find sides
oside={'Left','Right','Back','Front'};
bc=cell(4,1);
for i=1:numel(oside);
    bc{i}=pside([],G,oside{i},0);
    bc{i}= rmfield(bc{i},'type');
    bc{i}= rmfield(bc{i},'sat');
end
% finde node of the differens sides and prepare elastisity boundary
% conditions
for i=1:4
    inodes=mcolon(G.faces.nodePos(bc{i}.face),G.faces.nodePos(bc{i}.face+1)-1);
    nodes=unique(G.faces.nodes(inodes));
    disp_bc=struct('nodes',nodes,...
                    'uu',0,...
                    'faces',bc{i}.face,...
                    'uu_face',0,...
                    'mask',true(numel(nodes),G.griddim));
    bc{i}.el_bc=struct('disp_bc', disp_bc,'force_bc',[]);
end
%% define load as gravity
density=3000;% kg/m^3
grav=10;% gravity 
load=@(x) -(grav*density)*repmat([0,1],size(x,1),1);
% set boundary dispace ment function to zeros
bcdisp=@(x) x*0.0;


% set up boundary conditions for each side
clear bc_el_sides
% set direclet boundary conditions at selected sides
    % on left side nod displace ment in x direction only, this is done by
    % mask
    bc_el_sides{1}=bc{1}; 
    bc_el_sides{1}.el_bc.disp_bc.mask(:,2)=false;
    % same as x direction
    bc_el_sides{2}=bc{2};
    bc_el_sides{2}.el_bc.disp_bc.mask(:,2)=false;
    % no displace ment in y direction at the bottum
    bc_el_sides{3}=bc{3};
    bc_el_sides{3}.el_bc.disp_bc.mask(:,1)=false;
    bc_el_sides{4}=[];
    % remove    
    
% collect bounary conditions
nodes=[];
faces=[];
mask=[];
for i=1:numel(bc)
    if(~isempty(bc_el_sides{i}))
        nodes=[nodes;bc_el_sides{i}.el_bc.disp_bc.nodes];%#ok
        faces=[faces;bc_el_sides{i}.el_bc.disp_bc.faces];%#ok
        mask=[mask;bc_el_sides{i}.el_bc.disp_bc.mask];%#ok
    end
end
disp_node=bcdisp(G.nodes.coords(nodes,:));
disp_faces=bcdisp(G.faces.centroids(faces,:));
disp_bc=struct('nodes',nodes,'uu',disp_node,'faces',faces,'uu_face',disp_faces,'mask',mask); 
% define forces at boundary     
%find midpoint face set all force corresponding to the "weight fo the ting
%at limited area
sigma=opt.L(2)/10;force=100*barsa;
face_force =@(x) force*exp(-(((x(:,1)-opt.L(1)/2))./sigma).^2)+10*barsa;
faces=bc{4}.face;
% make force boundary structure NB force is in units Pa/m^3
force_bc=struct('faces',faces,'force',bsxfun(@times,face_force(G.faces.centroids(faces,:)),[0 -1]));    
% final structure fo boundary conditions
el_bc=struct('disp_bc',disp_bc,'force_bc',force_bc);


%% define rock parameters
Ev=repmat(opt.E,G.cells.num,1);nuv=repmat(opt.nu,G.cells.num,1);

C=Enu2C(Ev,nuv,G);
%[uu,p,S,A,extra]=VEM2D_linElast2f(G,C,el_bc,load,'dual_field',false);
[uu,extra]=VEM_linElast(G,C,el_bc,load);
As=extra.disc.A;
gradP=extra.disc.gradP;
div=extra.disc.div;
isdirdofs=extra.disc.isdirdofs;
rhs_s=extra.disc.rhs;
Vdir=extra.disc.V_dir;
ind_s=[1:size(As,1)]';%#ok


% find discretization of mechanics
% find discretizationin of flow
perm=1*darcy*ones(G.cartDims);
perm(:,floor(G.cartDims(2)/5):end)=1*milli*darcy;
rock=struct('perm',reshape(perm,[],1),'poro',0.1*ones(G.cells.num,1),'alpha',ones(G.cells.num,1));
fluid=initSingleFluid('mu',1*centi*poise,'rho',1000);
fluid.cr=1e-4/barsa;
T=computeTrans(G,rock);
pv=poreVolume(G,rock);
pressure=100*barsa*ones(G.cells.num,1);
state=struct('pressure',pressure,'s',ones(G.cells.num,1),'flux',zeros(G.faces.num,1));
dt=day*1e0;
mcoord=[5000 200];
[dd,wc]=min(sum(bsxfun(@minus,G.cells.centroids,mcoord).^2,2));
%sub=floor(G.cartDims/2);
%wc=sub2ind(G.cartDims,sub(1),sub(2));
W=addWell([],G,rock,wc,'type','bhp','val',3000*barsa);
bc_f=[];
%bc=pside(bc,G,'Left',100*barsa);
%bc=pside(bc,G,'Right',100*barsa);
bc_f=pside(bc_f,G,'Front',10*barsa);
%bc=[];
state = lincompTPFA(dt, state, G, T,pv, fluid, 'MatrixOutput',true,'wells',W,'bc',bc_f);
% definitions with out dt
Af=state.A;
orhsf=state.rhs;
ct=state.ct;
ind_f=[ind_s(end)+1:ind_s(end)+G.cells.num]';%#ok
x=zeros(ind_f(end),1);
x(ind_f)=pressure;
p=pressure;
t_ma=10*dt;t=0;
uu0=uu;
u_tmp=reshape(uu',[],1);
x(1:ind_s(end))=u_tmp(~isdirdofs);
u=zeros(numel(isdirdofs),1);
rhsf=zeros(size(orhsf));
plotops={'EdgeColor','none'};
fac=rock.poro(1);
while t < t_ma
    t=t+dt;
    %rhs_s do not change
    xo=x;
    rhsf(1:G.cells.num)=orhsf(1:G.cells.num)*dt+ct(1:G.cells.num,1:G.cells.num)*p+fac*div*x(ind_s);
    rhsf(G.cells.num+1:end)=orhsf(G.cells.num+1:end);
    % fake boundary 
    
    
    %fac=1e-1; % should be porosity ?? per cell
    % need to be shure not to set forces on the boundary from pressure of
    % fluid
    %p_bc=10*barsa;% assume depth and open boundary
    % set boundary pressure to 100 barsa need to be taken more care full
    % need to consider best way of handaling boundary condtion to get
    % symetric system ???, pressure calculations on boundary seems to be
    % nessesary to calculate correct gradient for pressure contribution to
    % force for the elasiticyt part
    fbc = addFluidContribMechVEM(G,bc_f,rock,isdirdofs);
    %{
    rhs=[rhs_s+fac*sum(gradP,2)*p_bc;
        rhsf];
    %}
    rhs=[rhs_s-fbc;
        rhsf];
    % to add bhp wells as separate variables
    mat=sparse(size(Af,1)-G.cells.num,size(div,2));
    SS=[As,[fac*(-gradP),mat'];...
        [fac*div; mat],ct+dt*Af];
    x=SS\rhs;
    p=x(ind_f);
    u(isdirdofs)=Vdir(isdirdofs);
    u(~isdirdofs)=x(ind_s);
    uu=reshape(u,G.griddim,[])';
    figure(1),clf
    subplot(2,2,1),cla
    plotNodeData(G,uu(:,1),plotops{:}),colorbar;
    subplot(2,2,2),cla
    plotNodeData(G,uu(:,2),plotops{:});colorbar
    subplot(2,2,3),cla
    plotCellDataDeformed(G,p/barsa,uu);colorbar
    subplot(2,2,4),cla
    ovdiv=extra.disc.ovol_div;
    mdiv=ovdiv*reshape(uu',[],1)./G.cells.volumes;
    plotCellDataDeformed(G,mdiv,uu);colorbar(),
    %
    figure(2),clf
    uur=uu-uu0;
    subplot(2,2,1),cla
    plotNodeData(G,uur(:,1),plotops{:}),colorbar;
    subplot(2,2,2),cla
    plotNodeData(G,uur(:,2),plotops{:});colorbar
    subplot(2,2,3),cla
    plotCellDataDeformed(G,p/barsa,uur);colorbar
    subplot(2,2,4),cla
    ovdiv=extra.disc.ovol_div;
    mdiv=ovdiv*reshape(uur',[],1)./G.cells.volumes;
    plotCellDataDeformed(G,mdiv,uu);colorbar(),   
    pause(0.01);
end
return
%% define problem probelm an run it in the solver
problem=struct('G',G,'W',W,'bc_f',bc_f,'fluid',fluid,'rock',rock,...
               'Ev',Ev,'nuv',nuv,'el_bc',el_bc,'load',load);
           % use Ev an muv for now
pressure=100*barsa*ones(G.cells.num,1);
state0=struct('pressure',pressure,'s',ones(G.cells.num,1),'flux',zeros(G.faces.num,1),'uu',uu0);
schedule=struct('dt_steps',dt*ones(10,1));
states=poroElastisityLinear(state0,G,problem,schedule,'do_plot',true)
%%
figure(1),clf,
fac=10;% plot deformed grid with a factor 10 for dispalcement compeared with initial state
for i=1:numel(states)
    %clf,plotCellDataDeformed(G,states{i}.pressure/barsa,states{i}.uu*fac),colorbar
    clf,plotCellDataDeformed(G,states{i}.pressure/barsa,state0.uu+(states{i}.uu-state0.uu)*fac),colorbar
    title(['Time', num2str(states{i}.t/day),' dayes'])
    pause(0.1)
end


%% here is the lines for discretization
% can it be generalized to all types of solvers??

%% set up porouse media flow discretization using tpfa
T=computeTrans(G,problem.rock);
pv=poreVolume(G,problem.rock);
pressure=100*barsa*ones(G.cells.num,1);
state_f=struct('pressure',pressure,'s',ones(G.cells.num,1),'flux',zeros(G.faces.num,1));
dt=1e-3*day;%fake
state_f = lincompTPFA(dt, state_f, G, T, pv, problem.fluid, 'MatrixOutput',true,'wells',problem.W,'bc',problem.bc_f);
%% set up discretization soluid using VEM
[uu,p,S,A,extra]=VEM2D_linElast2f(G,problem.Ev,problem.nuv,el_bc,problem.load,'dual_field',false);
disc_f=struct('A',state_f.A,'rhs',state_f.rhs,'ct',state.ct);
disc=struct('disc_s',extra.disc,'disc_f',disc_f);
 


