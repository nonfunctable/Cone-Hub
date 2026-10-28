
local a,b={{1,'ModuleScript',{'MainModule'},{{18,'ModuleScript',{'Creator'}},{28,'ModuleScript',{'Icons'}},{47,'ModuleScript',{'Themes'},{{50,'ModuleScript',{'Dark'}},{52,'ModuleScript',{'Light'}},{51,'ModuleScript',{'Darker'}},{53,'ModuleScript',{'Rose'}},{49,'ModuleScript',{'Aqua'}},{48,'ModuleScript',{'Amethyst'}}}},{19,'ModuleScript',{'Elements'},{{21,'ModuleScript',{'Colorpicker'}},{27,'ModuleScript',{'Toggle'}},{23,'ModuleScript',{'Input'}},{20,'ModuleScript',{'Button'}},{25,'ModuleScript',{'Paragraph'}},{22,'ModuleScript',{'Dropdown'}},{26,'ModuleScript',{'Slider'}},{24,'ModuleScript',{'Keybind'}},{54,'ModuleScript',{'Divider'}},{55,'ModuleScript',{'StatCard'}}}},{29,'Folder',{'Packages'},{{30,'ModuleScript',{'Flipper'},{{33,'ModuleScript',{'GroupMotor'}},{46,'ModuleScript',{'isMotor.spec'}},{39,'ModuleScript',{'Signal'}},{40,'ModuleScript',{'Signal.spec'}},{45,'ModuleScript',{'isMotor'}},{36,'ModuleScript',{'Instant.spec'}},{44,'ModuleScript',{'Spring.spec'}},{42,'ModuleScript',{'SingleMotor.spec'}},{38,'ModuleScript',{'Linear.spec'}},{31,'ModuleScript',{'BaseMotor'}},{43,'ModuleScript',{'Spring'}},{35,'ModuleScript',{'Instant'}},{37,'ModuleScript',{'Linear'}},{41,'ModuleScript',{'SingleMotor'}},{34,'ModuleScript',{'GroupMotor.spec'}},{32,'ModuleScript',{'BaseMotor.spec'}}}}}},{2,'ModuleScript',{'Acrylic'},{{3,'ModuleScript',{'AcrylicBlur'}},{5,'ModuleScript',{'CreateAcrylic'}},{6,'ModuleScript',{'Utils'}},{4,'ModuleScript',{'AcrylicPaint'}}}},{7,'Folder',{'Components'},{{9,'ModuleScript',{'Button'}},{12,'ModuleScript',{'Notification'}},{13,'ModuleScript',{'Section'}},{17,'ModuleScript',{'Window'}},{14,'ModuleScript',{'Tab'}},{10,'ModuleScript',{'Dialog'}},{8,'ModuleScript',{'Assets'}},{16,'ModuleScript',{'TitleBar'}},{15,'ModuleScript',{'Textbox'}},{11,'ModuleScript',{'Element'}}}}}}}
local aa={
[1]=function()
local c,d,e,f,g=b(1)
local Lighting=game:GetService'Lighting'
local RunService=game:GetService'RunService'
local LocalPlayer=game:GetService'Players'.LocalPlayer
local UserInputService=game:GetService'UserInputService'
local TweenService=game:GetService'TweenService'
local Camera=game:GetService'Workspace'.CurrentCamera
local Mouse=LocalPlayer:GetMouse()
local RootModule=d
local Creator=e(RootModule.Creator)
local ElementsList=e(RootModule.Elements)
local Acrylic=e(RootModule.Acrylic)
local Components=RootModule.Components
local Notification=e(Components.Notification)
local New=Creator.New
local ProtectGui=protectgui or(syn and syn.protect_gui)or function()end

if getgenv and getgenv().Fluent and type(getgenv().Fluent.Destroy)=='function'then
    pcall(function()getgenv().Fluent:Destroy()end)
end

local GUI=New('ScreenGui',{
    Name='ConeHub_Fluent',
    DisplayOrder=100,
    Parent=(gethui and gethui())or(RunService:IsStudio()and LocalPlayer.PlayerGui or game:GetService'CoreGui')
})
ProtectGui(GUI)
Notification:Init(GUI)

local Library={
    Version='1.2.0',
    OpenFrames={},
    OpenDropdowns={},
    Options={},
    Themes=e(RootModule.Themes).Names,
    Window=nil,
    WindowFrame=nil,
    Unloaded=false,
    Theme='Dark',
    DialogOpen=false,
    UseAcrylic=false,
    Acrylic=false,
    Transparency=true,
    MinimizeKeybind=nil,
    MinimizeKey=Enum.KeyCode.LeftControl,
    GUI=GUI
}

function Library.CloseAllDropdowns(self,except)
    for _,dd in ipairs(Library.OpenDropdowns)do
        if dd~=except and dd.Opened then
            pcall(function()dd:Close()end)
        end
    end
end

function Library.SafeCallback(self,callback,...)
    if not callback then return end
    local ok,err=pcall(callback,...)
    if not ok then
        local _,endIdx=err:find':%d+: '
        if not endIdx then
            return Library:Notify{Title='Interface',Content='Callback error',SubContent=tostring(err),Duration=5}
        end
        return Library:Notify{Title='Interface',Content='Callback error',SubContent=err:sub(endIdx+1),Duration=5}
    end
end

function Library.Round(self,num,decimals)
    if decimals==0 then return math.floor(num)end
    local s=tostring(num)
    return s:find'%.'and tonumber(s:sub(1,s:find'%.'+decimals))or num
end

local IconAssets=e(RootModule.Icons).assets
function Library.GetIcon(self,name)
    if name==nil or name==''then return nil end
    local s=tostring(name)
    if IconAssets['lucide-'..s]then return IconAssets['lucide-'..s]end
    if IconAssets[s]then return IconAssets[s]end
    if s:find'^rbxassetid://'or s:find'^http'then return s end
    if tonumber(s)then return'rbxassetid://'..s end
    return nil
end

local TooltipOwner=nil
local TooltipFrame=nil
local TooltipLabel=nil
local TooltipMoveConn=nil

local function EnsureTooltip()
    if TooltipFrame and TooltipFrame.Parent then return end
    TooltipLabel=New('TextLabel',{
        FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Regular,Enum.FontStyle.Normal),
        Text='',
        TextSize=12,
        TextWrapped=true,
        RichText=true,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top,
        AutomaticSize=Enum.AutomaticSize.XY,
        Size=UDim2.fromOffset(0,0),
        BackgroundTransparency=1,
        ZIndex=201,
        ThemeTag={TextColor3='Text'}
    })
    TooltipFrame=New('Frame',{
        Name='FluentTooltip',
        Visible=false,
        ZIndex=200,
        AutomaticSize=Enum.AutomaticSize.XY,
        Size=UDim2.fromOffset(0,0),
        BackgroundTransparency=0.04,
        Parent=GUI,
        ThemeTag={BackgroundColor3='DropdownHolder'}
    },{
        New('UICorner',{CornerRadius=UDim.new(0,6)}),
        New('UIStroke',{Thickness=1,Transparency=0.35,ThemeTag={Color='Accent'}}),
        New('UIPadding',{
            PaddingLeft=UDim.new(0,9),
            PaddingRight=UDim.new(0,9),
            PaddingTop=UDim.new(0,6),
            PaddingBottom=UDim.new(0,6)
        }),
        New('UISizeConstraint',{MaxSize=Vector2.new(260,300)}),
        TooltipLabel
    })
end

local function UpdateTooltipPos()
    if not TooltipFrame or not TooltipFrame.Visible then return end
    local vp=Camera and Camera.ViewportSize or Vector2.new(1920,1080)
    local sz=TooltipFrame.AbsoluteSize
    local x=Mouse.X+14
    local y=Mouse.Y+16
    if x+sz.X+8>vp.X then x=math.max(8,Mouse.X-sz.X-10)end
    if y+sz.Y+8>vp.Y then y=math.max(8,Mouse.Y-sz.Y-10)end
    TooltipFrame.Position=UDim2.fromOffset(x,y)
end

function Library.ShowTooltip(self,text,owner)
    if not text or text==''or Library.Unloaded then return end
    EnsureTooltip()
    TooltipOwner=owner
    TooltipLabel.Text=tostring(text)
    TooltipFrame.Visible=true
    UpdateTooltipPos()
    if not TooltipMoveConn then
        TooltipMoveConn=UserInputService.InputChanged:Connect(function(input)
            if Library.Unloaded then
                if TooltipMoveConn then TooltipMoveConn:Disconnect()TooltipMoveConn=nil end
                return
            end
            if TooltipFrame and TooltipFrame.Visible and(input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then
                UpdateTooltipPos()
            end
        end)
    end
end

function Library.HideTooltip(self,owner)
    if owner==nil or TooltipOwner==owner then
        TooltipOwner=nil
        if TooltipFrame then TooltipFrame.Visible=false end
        if TooltipMoveConn then
            TooltipMoveConn:Disconnect()
            TooltipMoveConn=nil
        end
    end
end

local ElementsMT={}
ElementsMT.__index=ElementsMT
ElementsMT.__namecall=function(tbl,key,...)
    return ElementsMT[key](...)
end

for _,elemModule in ipairs(ElementsList)do
    ElementsMT['Add'..elemModule.__type]=function(containerCtx,arg1,arg2)
        elemModule.Container=containerCtx.Container
        elemModule.Type=containerCtx.Type
        elemModule.ScrollFrame=containerCtx.ScrollFrame
        elemModule.Library=Library
        elemModule.Context=containerCtx
        return elemModule:New(arg1,arg2)
    end
end
ElementsMT.AddStatGrid=ElementsMT.AddStatCard
ElementsMT.AddSeparator=ElementsMT.AddDivider

Library.Elements=ElementsMT

function Library.CreateWindow(self,config)
    assert(config.Title,'Window - Missing Title')
    if Library.Window then
        print'You cannot create more than one window.'
        return
    end
    Library.MinimizeKey=config.MinimizeKey or Enum.KeyCode.LeftControl
    Library.UseAcrylic=config.Acrylic
    if config.Acrylic then Acrylic.init()end
    local win=e(Components.Window){
        Parent=GUI,
        Size=config.Size,
        Title=config.Title,
        SubTitle=config.SubTitle,
        TabWidth=config.TabWidth,
        Search=config.Search
    }
    Library.Window=win
    Library:SetTheme(config.Theme)
    return win
end

function Library.SetTheme(self,themeName)
    if Library.Window and table.find(Library.Themes,themeName)then
        Library.Theme=themeName
        Creator.UpdateTheme()
    end
end

function Library.Destroy(self)
    Library.Unloaded=true
    Library:HideTooltip()
    pcall(function()
        local fl=e(RootModule.Packages.Flipper)
        if fl and fl.SingleMotor and fl.SingleMotor.stopAll then
            fl.SingleMotor.stopAll()
        end
    end)
    if Library.Window and Library.UseAcrylic and Library.Window.AcrylicPaint and Library.Window.AcrylicPaint.Model then
        pcall(function()Library.Window.AcrylicPaint.Model:Destroy()end)
    end
    pcall(Creator.Disconnect)
    if Library.GUI then
        pcall(function()
            Library.GUI.Enabled=false
            Library.GUI:Destroy()
        end)
    end
end

function Library.ToggleAcrylic(self,state)
    if Library.Window then
        if Library.UseAcrylic then
            Library.Acrylic=state
            Library.Window.AcrylicPaint.Model.Transparency=state and 0.98 or 1
            if state then Acrylic.Enable()else Acrylic.Disable()end
        end
    end
end

function Library.ToggleTransparency(self,state)
    if Library.Window then
        Library.Window.AcrylicPaint.Frame.Background.BackgroundTransparency=state and 0.35 or 0
    end
end

function Library.Notify(self,config)
    return Notification:New(config)
end

if getgenv then getgenv().Fluent=Library end
return Library
end,
[2]=function()local c,d,e,f,g=b(2)local h={AcrylicBlur=e(d.AcrylicBlur),CreateAcrylic=e(d.CreateAcrylic),AcrylicPaint=e(d.AcrylicPaint)}function h.init()local i=Instance.new'DepthOfFieldEffect'i.FarIntensity=0 i.InFocusRadius=0.1 i.NearIntensity=1 local j={}function h.Enable()for k,l in pairs(j)do l.Enabled=false end i.Parent=game:GetService'Lighting'end function h.Disable()for k,l in pairs(j)do l.Enabled=l.enabled end i.Parent=nil end local k=function()local k=function(k)if k:IsA'DepthOfFieldEffect'then j[k]={enabled=k.Enabled}end end for l,m in pairs(game:GetService'Lighting':GetChildren())do k(m)end if game:GetService'Workspace'.CurrentCamera then for n,o in pairs(game:GetService'Workspace'.CurrentCamera:GetChildren())do k(o)end end end k()h.Enable()end return h end,
[3]=function()local c,d,e,f,g=b(3)local h,i,j,k=e(d.Parent.Parent.Creator),e(d.Parent.CreateAcrylic),unpack(e(d.Parent.Utils))local l=function(l)local m={}l=l or 0.001 local n,o={topLeft=Vector2.new(),topRight=Vector2.new(),bottomRight=Vector2.new()},i()o.Parent=workspace local p,q=function(p,q)n.topLeft=q n.topRight=q+Vector2.new(p.X,0)n.bottomRight=q+p end,function()local p=game:GetService'Workspace'.CurrentCamera if p then p=p.CFrame end local q=p if not q then q=CFrame.new()end local r,s,t,u=q,n.topLeft,n.topRight,n.bottomRight local v,w,x=j(s,l),j(t,l),j(u,l)local y,z=(w-v).Magnitude,(w-x).Magnitude o.CFrame=CFrame.fromMatrix((v+x)/2,r.XVector,r.YVector,r.ZVector)o.Mesh.Scale=Vector3.new(y,z,0)end local r,s=function(r)local s=k()local t,u=r.AbsoluteSize-Vector2.new(s,s),r.AbsolutePosition+Vector2.new(s/2,s/2)p(t,u)task.spawn(q)end,function()local r=game:GetService'Workspace'.CurrentCamera if not r then return end table.insert(m,r:GetPropertyChangedSignal'CFrame':Connect(q))table.insert(m,r:GetPropertyChangedSignal'ViewportSize':Connect(q))table.insert(m,r:GetPropertyChangedSignal'FieldOfView':Connect(q))task.spawn(q)end o.Destroying:Connect(function()for t,u in m do pcall(function()u:Disconnect()end)end end)s()return r,o end return function(m)local n,o,p={},l(m)local q=h.New('Frame',{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})h.AddSignal(q:GetPropertyChangedSignal'AbsolutePosition',function()o(q)end)h.AddSignal(q:GetPropertyChangedSignal'AbsoluteSize',function()o(q)end)n.AddParent=function(r)h.AddSignal(r:GetPropertyChangedSignal'Visible',function()n.SetVisibility(r.Visible)end)end n.SetVisibility=function(r)p.Transparency=r and 0.98 or 1 end n.Frame=q n.Model=p return n end end,
[4]=function()local c,d,e,f,g=b(4)local h,i=e(d.Parent.Parent.Creator),e(d.Parent.AcrylicBlur)local j=h.New return function(k)local l={}l.Frame=j('Frame',{Size=UDim2.fromScale(1,1),BackgroundTransparency=0.9,BackgroundColor3=Color3.fromRGB(255,255,255),BorderSizePixel=0},{j('ImageLabel',{Image='rbxassetid://8992230677',ScaleType='Slice',SliceCenter=Rect.new(Vector2.new(99,99),Vector2.new(99,99)),AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.new(1,120,1,116),Position=UDim2.new(0.5,0,0.5,0),BackgroundTransparency=1,ImageColor3=Color3.fromRGB(0,0,0),ImageTransparency=0.7}),j('UICorner',{CornerRadius=UDim.new(0,8)}),j('Frame',{BackgroundTransparency=0.45,Size=UDim2.fromScale(1,1),Name='Background',ThemeTag={BackgroundColor3='AcrylicMain'}},{j('UICorner',{CornerRadius=UDim.new(0,8)})}),j('Frame',{BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=0.4,Size=UDim2.fromScale(1,1)},{j('UICorner',{CornerRadius=UDim.new(0,8)}),j('UIGradient',{Rotation=90,ThemeTag={Color='AcrylicGradient'}})}),j('ImageLabel',{Image='rbxassetid://9968344105',ImageTransparency=0.98,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.new(0,128,0,128),Size=UDim2.fromScale(1,1),BackgroundTransparency=1},{j('UICorner',{CornerRadius=UDim.new(0,8)})}),j('ImageLabel',{Image='rbxassetid://9968344227',ImageTransparency=0.9,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.new(0,128,0,128),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ThemeTag={ImageTransparency='AcrylicNoise'}},{j('UICorner',{CornerRadius=UDim.new(0,8)})}),j('Frame',{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=2},{j('UICorner',{CornerRadius=UDim.new(0,8)}),j('UIStroke',{Transparency=0.5,Thickness=1,ThemeTag={Color='AcrylicBorder'}})})})local m if e(d.Parent.Parent).UseAcrylic then m=i()m.Frame.Parent=l.Frame l.Model=m.Model l.AddParent=m.AddParent l.SetVisibility=m.SetVisibility end return l end end,
[5]=function()local c,d,e,f,g=b(5)local h=d.Parent.Parent local i=e(h.Creator)local j=function()local j=i.New('Part',{Name='Body',Color=Color3.new(0,0,0),Material=Enum.Material.Glass,Size=Vector3.new(1,1,0),Anchored=true,CanCollide=false,Locked=true,CastShadow=false,Transparency=0.98},{i.New('SpecialMesh',{MeshType=Enum.MeshType.Brick,Offset=Vector3.new(0,0,-1E-6)})})return j end return j end,
[6]=function()local c,d,e,f,g=b(6)local h,i=function(h,i,j,k,l)return(h-i)*(l-k)/(j-i)+k end,function(h,i)local j=game:GetService'Workspace'.CurrentCamera:ScreenPointToRay(h.X,h.Y)return j.Origin+j.Direction*i end local j=function()local j=game:GetService'Workspace'.CurrentCamera.ViewportSize.Y return h(j,0,2560,8,56)end return{i,j}end,
[8]=function()local c,d,e,f,g=b(8)return{Close='rbxassetid://9886659671',Min='rbxassetid://9886659276',Max='rbxassetid://9886659406',Restore='rbxassetid://9886659001'}end,
[9]=function()local c,d,e,f,g=b(9)local h=d.Parent.Parent local i,j=e(h.Packages.Flipper),e(h.Creator)local k,l=j.New,i.Spring.new return function(m,n,o)o=o or false local p={}p.Title=k('TextLabel',{FontFace=Font.new'rbxasset://fonts/families/GothamSSm.json',TextColor3=Color3.fromRGB(200,200,200),TextSize=14,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,BackgroundColor3=Color3.fromRGB(255,255,255),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ThemeTag={TextColor3='Text'}})p.HoverFrame=k('Frame',{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ThemeTag={BackgroundColor3='Hover'}},{k('UICorner',{CornerRadius=UDim.new(0,4)})})p.Frame=k('TextButton',{Size=UDim2.new(0,0,0,32),Parent=n,ThemeTag={BackgroundColor3='DialogButton'}},{k('UICorner',{CornerRadius=UDim.new(0,4)}),k('UIStroke',{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Transparency=0.65,ThemeTag={Color='DialogButtonBorder'}}),p.HoverFrame,p.Title})local q,r=j.SpringMotor(1,p.HoverFrame,'BackgroundTransparency',o)j.AddSignal(p.Frame.MouseEnter,function()r(0.97)end)j.AddSignal(p.Frame.MouseLeave,function()r(1)end)j.AddSignal(p.Frame.MouseButton1Down,function()r(1)end)j.AddSignal(p.Frame.MouseButton1Up,function()r(0.97)end)return p end end,
[10]=function()local c,d,e,f,g=b(10)local h,i,j,k=game:GetService'UserInputService',game:GetService'Players'.LocalPlayer:GetMouse(),game:GetService'Workspace'.CurrentCamera,d.Parent.Parent local l,m=e(k.Packages.Flipper),e(k.Creator)local n,o,p,q=l.Spring.new,l.Instant.new,m.New,{Window=nil}function q.Init(r,s)q.Window=s return q end function q.Create(r)local s={Buttons=0}s.TintFrame=p('TextButton',{Text='',Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,Parent=q.Window.Root},{p('UICorner',{CornerRadius=UDim.new(0,8)})})local t,u=m.SpringMotor(1,s.TintFrame,'BackgroundTransparency',true)s.ButtonHolder=p('Frame',{Size=UDim2.new(1,-40,1,-40),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundTransparency=1},{p('UIListLayout',{Padding=UDim.new(0,10),FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder})})s.ButtonHolderFrame=p('Frame',{Size=UDim2.new(1,0,0,70),Position=UDim2.new(0,0,1,-70),ThemeTag={BackgroundColor3='DialogHolder'}},{p('Frame',{Size=UDim2.new(1,0,0,1),ThemeTag={BackgroundColor3='DialogHolderLine'}}),s.ButtonHolder})s.Title=p('TextLabel',{FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal),Text='Dialog',TextColor3=Color3.fromRGB(240,240,240),TextSize=22,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,22),Position=UDim2.fromOffset(20,25),BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=1,ThemeTag={TextColor3='Text'}})s.Scale=p('UIScale',{Scale=1})local v,w=m.SpringMotor(1.1,s.Scale,'Scale')s.Root=p('CanvasGroup',{Size=UDim2.fromOffset(300,165),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),GroupTransparency=1,Parent=s.TintFrame,ThemeTag={BackgroundColor3='Dialog'}},{p('UICorner',{CornerRadius=UDim.new(0,8)}),p('UIStroke',{Transparency=0.5,ThemeTag={Color='DialogBorder'}}),s.Scale,s.Title,s.ButtonHolderFrame})local x,y=m.SpringMotor(1,s.Root,'GroupTransparency')function s.Open(z)e(k).DialogOpen=true s.Scale.Scale=1.1 u(0.75)y(0)w(1)end function s.Close(z)e(k).DialogOpen=false u(1)y(1)w(1.1)s.Root.UIStroke:Destroy()task.wait(0.15)s.TintFrame:Destroy()end function s.Button(z,A,B)s.Buttons=s.Buttons+1 A=A or'Button'B=B or function()end local C=e(k.Components.Button)('',s.ButtonHolder,true)C.Title.Text=A for D,E in next,s.ButtonHolder:GetChildren()do if E:IsA'TextButton'then E.Size=UDim2.new(1/s.Buttons,-(((s.Buttons-1)*10)/s.Buttons),0,32)end end m.AddSignal(C.Frame.MouseButton1Click,function()e(k):SafeCallback(B)pcall(function()s:Close()end)end)return C end return s end return q end,
[11]=function()
local c,d,e,f,g=b(11)
local Root=d.Parent.Parent
local Flipper=e(Root.Packages.Flipper)
local Creator=e(Root.Creator)
local New=Creator.New

return function(title,desc,parent,hoverable)
    local Elem={
        TitleText=tostring(title or''),
        DescText=tostring(desc or''),
        TooltipText='',
        Locked=false,
        LockReason=nil,
        UserVisible=true,
        SearchVisible=true
    }

    Elem.TitleLabel=New('TextLabel',{
        FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Medium,Enum.FontStyle.Normal),
        Text=Elem.TitleText,
        RichText=true,
        TextColor3=Color3.fromRGB(240,240,240),
        TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.fromOffset(0,14),
        AutomaticSize=Enum.AutomaticSize.X,
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BackgroundTransparency=1,
        ThemeTag={TextColor3='Text'}
    })

    Elem.TooltipIcon=New('ImageLabel',{
        Image='rbxassetid://10723415903',
        Size=UDim2.fromOffset(13,13),
        BackgroundTransparency=1,
        ImageTransparency=0.35,
        Visible=false,
        LayoutOrder=2,
        ThemeTag={ImageColor3='SubText'}
    })

    Elem.TitleRow=New('Frame',{
        Size=UDim2.new(1,0,0,14),
        BackgroundTransparency=1,
        LayoutOrder=1
    },{
        New('UIListLayout',{
            FillDirection=Enum.FillDirection.Horizontal,
            SortOrder=Enum.SortOrder.LayoutOrder,
            VerticalAlignment=Enum.VerticalAlignment.Center,
            Padding=UDim.new(0,5)
        }),
        Elem.TitleLabel,
        Elem.TooltipIcon
    })

    Elem.DescLabel=New('TextLabel',{
        FontFace=Font.new'rbxasset://fonts/families/GothamSSm.json',
        Text=Elem.DescText,
        RichText=true,
        TextColor3=Color3.fromRGB(200,200,200),
        TextSize=12,
        TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left,
        BackgroundColor3=Color3.fromRGB(255,255,255),
        AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,14),
        LayoutOrder=2,
        ThemeTag={TextColor3='SubText'}
    })

    Elem.LabelHolder=New('Frame',{
        AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BackgroundTransparency=1,
        Position=UDim2.fromOffset(10,0),
        Size=UDim2.new(1,-28,0,0)
    },{
        New('UIListLayout',{
            SortOrder=Enum.SortOrder.LayoutOrder,
            VerticalAlignment=Enum.VerticalAlignment.Center,
            Padding=UDim.new(0,2)
        }),
        New('UIPadding',{
            PaddingBottom=UDim.new(0,13),
            PaddingTop=UDim.new(0,13)
        }),
        Elem.TitleRow,
        Elem.DescLabel
    })

    Elem.Border=New('UIStroke',{
        Transparency=0.5,
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
        Color=Color3.fromRGB(0,0,0),
        ThemeTag={Color='ElementBorder'}
    })

    Elem.Frame=New('TextButton',{
        Size=UDim2.new(1,0,0,0),
        BackgroundTransparency=0.89,
        BackgroundColor3=Color3.fromRGB(130,130,130),
        Parent=parent,
        AutomaticSize=Enum.AutomaticSize.Y,
        Text='',
        LayoutOrder=7,
        ThemeTag={
            BackgroundColor3='Element',
            BackgroundTransparency='ElementTransparency'
        }
    },{
        New('UICorner',{CornerRadius=UDim.new(0,4)}),
        Elem.Border,
        Elem.LabelHolder
    })

    function Elem.SetTitle(self,newTitle)
        Elem.TitleText=tostring(newTitle or'')
        Elem.TitleLabel.Text=Elem.TitleText
    end

    function Elem.SetDesc(self,newDesc)
        if newDesc==nil then newDesc=''end
        Elem.DescText=tostring(newDesc)
        Elem.DescLabel.Visible=(Elem.DescText~='')
        Elem.DescLabel.Text=Elem.DescText
    end

    function Elem.SetTooltip(self,text)
        Elem.TooltipText=tostring(text or'')
        Elem.TooltipIcon.Visible=(Elem.TooltipText~='')
    end

    function Elem.SetLocked(self,locked,reason)
        Elem.Locked=not not locked
        Elem.LockReason=reason
        if Elem.Locked then
            if not Elem.LockOverlay then
                Elem.LockReasonLabel=New('TextLabel',{
                    FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Medium,Enum.FontStyle.Normal),
                    Text='Locked',
                    TextSize=11,
                    AutomaticSize=Enum.AutomaticSize.X,
                    Size=UDim2.fromOffset(0,14),
                    BackgroundTransparency=1,
                    ZIndex=17,
                    LayoutOrder=2,
                    ThemeTag={TextColor3='SubText'}
                })
                local badge=New('Frame',{
                    Position=UDim2.new(1,-10,0.5,0),
                    AnchorPoint=Vector2.new(1,0.5),
                    AutomaticSize=Enum.AutomaticSize.X,
                    Size=UDim2.fromOffset(0,22),
                    BackgroundTransparency=0.12,
                    ZIndex=16,
                    ThemeTag={BackgroundColor3='DropdownHolder'}
                },{
                    New('UICorner',{CornerRadius=UDim.new(0,5)}),
                    New('UIStroke',{Thickness=1,Transparency=0.45,ThemeTag={Color='InElementBorder'}}),
                    New('UIPadding',{PaddingLeft=UDim.new(0,7),PaddingRight=UDim.new(0,7)}),
                    New('UIListLayout',{
                        FillDirection=Enum.FillDirection.Horizontal,
                        VerticalAlignment=Enum.VerticalAlignment.Center,
                        SortOrder=Enum.SortOrder.LayoutOrder,
                        Padding=UDim.new(0,5)
                    }),
                    New('ImageLabel',{
                        Image='rbxassetid://10723434711',
                        Size=UDim2.fromOffset(12,12),
                        BackgroundTransparency=1,
                        ZIndex=17,
                        LayoutOrder=1,
                        ThemeTag={ImageColor3='Accent'}
                    }),
                    Elem.LockReasonLabel
                })
                Elem.LockOverlay=New('TextButton',{
                    Name='LockOverlay',
                    Size=UDim2.fromScale(1,1),
                    BackgroundColor3=Color3.fromRGB(10,10,14),
                    BackgroundTransparency=0.38,
                    Text='',
                    AutoButtonColor=false,
                    Active=true,
                    ZIndex=15,
                    Parent=Elem.Frame
                },{
                    New('UICorner',{CornerRadius=UDim.new(0,4)}),
                    badge
                })
            end
            Elem.LockReasonLabel.Text=(reason and tostring(reason)~='')and tostring(reason)or'Locked'
            Elem.LockOverlay.Visible=true
        elseif Elem.LockOverlay then
            Elem.LockOverlay.Visible=false
        end
        if Elem.OnLockChanged then
            pcall(Elem.OnLockChanged,Elem.Locked,Elem.LockReason)
        end
    end

    function Elem.Lock(self,reason)
        return Elem:SetLocked(true,reason)
    end

    function Elem.Unlock(self)
        return Elem:SetLocked(false)
    end

    function Elem.SetDisabled(self,disabled,reason)
        return Elem:SetLocked(disabled,reason)
    end

    function Elem.UpdateVisibility(self)
        local vis=(Elem.UserVisible~=false)and(Elem.SearchVisible~=false)
        Elem.Frame.Visible=vis
        if not vis then
            pcall(function()e(Root):HideTooltip(Elem.Frame)end)
        end
        if Elem.OnVisibilityChanged then
            pcall(Elem.OnVisibilityChanged,vis)
        end
    end

    function Elem.SetVisible(self,vis)
        Elem.UserVisible=(vis~=false)
        Elem:UpdateVisibility()
    end

    function Elem.GetSearchText(self)
        local t=(Elem.TitleLabel.Text or'')..' '..(Elem.DescLabel.Text or'')..' '..(Elem.TooltipText or'')..' '..(Elem.ExtraSearchText or'')
        return t:gsub('<[^>]+>',''):lower()
    end

    function Elem.Destroy(self)
        pcall(function()e(Root):HideTooltip(Elem.Frame)end)
        Elem.Frame:Destroy()
    end

    Elem:SetTitle(title)
    Elem:SetDesc(desc)

    local hoverMotor,setHoverGoal
    if hoverable then
        hoverMotor,setHoverGoal=Creator.SpringMotor(
            Creator.GetThemeProperty'ElementTransparency',
            Elem.Frame,
            'BackgroundTransparency',
            false,
            true
        )
        Creator.AddSignal(Elem.Frame.MouseButton1Down,function()
            if Elem.Locked then return end
            setHoverGoal(Creator.GetThemeProperty'ElementTransparency'+Creator.GetThemeProperty'HoverChange')
        end)
        Creator.AddSignal(Elem.Frame.MouseButton1Up,function()
            if Elem.Locked then return end
            setHoverGoal(Creator.GetThemeProperty'ElementTransparency'-Creator.GetThemeProperty'HoverChange')
        end)
    end

    Creator.AddSignal(Elem.Frame.MouseEnter,function()
        if hoverable and not Elem.Locked then
            setHoverGoal(Creator.GetThemeProperty'ElementTransparency'-Creator.GetThemeProperty'HoverChange')
        end
        if Elem.TooltipText and Elem.TooltipText~=''then
            e(Root):ShowTooltip(Elem.TooltipText,Elem.Frame)
        end
    end)

    Creator.AddSignal(Elem.Frame.MouseLeave,function()
        if hoverable then
            setHoverGoal(Creator.GetThemeProperty'ElementTransparency')
        end
        if Elem.TooltipText and Elem.TooltipText~=''then
            e(Root):HideTooltip(Elem.Frame)
        end
    end)

    return Elem
end
end,
[12]=function()local c,d,e,f,g=b(12)local h=d.Parent.Parent local i,j,k=e(h.Packages.Flipper),e(h.Creator),e(h.Acrylic)local l,m,n,o=i.Spring.new,i.Instant.new,j.New,{}function o.Init(p,q)o.Holder=n('Frame',{Position=UDim2.new(1,-30,1,-30),Size=UDim2.new(0,310,1,-30),AnchorPoint=Vector2.new(1,1),BackgroundTransparency=1,Parent=q},{n('UIListLayout',{HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Bottom,Padding=UDim.new(0,20)})})end function o.New(p,q)q.Title=q.Title or'Title'q.Content=q.Content or'Content'q.SubContent=q.SubContent or''q.Duration=q.Duration or nil q.Buttons=q.Buttons or{}local r={Closed=false}r.AcrylicPaint=k.AcrylicPaint()r.Title=n('TextLabel',{Position=UDim2.new(0,14,0,17),Text=q.Title,RichText=true,TextColor3=Color3.fromRGB(255,255,255),TextTransparency=0,FontFace=Font.new'rbxasset://fonts/families/GothamSSm.json',TextSize=13,TextXAlignment='Left',TextYAlignment='Center',Size=UDim2.new(1,-12,0,12),TextWrapped=true,BackgroundTransparency=1,ThemeTag={TextColor3='Text'}})r.ContentLabel=n('TextLabel',{FontFace=Font.new'rbxasset://fonts/families/GothamSSm.json',Text=q.Content,TextColor3=Color3.fromRGB(240,240,240),TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,14),BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=1,TextWrapped=true,ThemeTag={TextColor3='Text'}})r.SubContentLabel=n('TextLabel',{FontFace=Font.new'rbxasset://fonts/families/GothamSSm.json',Text=q.SubContent,TextColor3=Color3.fromRGB(240,240,240),TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,14),BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=1,TextWrapped=true,ThemeTag={TextColor3='SubText'}})r.LabelHolder=n('Frame',{AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=1,Position=UDim2.fromOffset(14,40),Size=UDim2.new(1,-28,0,0)},{n('UIListLayout',{SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,3)}),r.ContentLabel,r.SubContentLabel})r.CloseButton=n('TextButton',{Text='',Position=UDim2.new(1,-14,0,13),Size=UDim2.fromOffset(20,20),AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1},{n('ImageLabel',{Image=e(d.Parent.Assets).Close,Size=UDim2.fromOffset(16,16),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,ThemeTag={ImageColor3='Text'}})})r.Root=n('Frame',{BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Position=UDim2.fromScale(1,0)},{r.AcrylicPaint.Frame,r.Title,r.CloseButton,r.LabelHolder})if q.Content==''then r.ContentLabel.Visible=false end if q.SubContent==''then r.SubContentLabel.Visible=false end r.Holder=n('Frame',{BackgroundTransparency=1,Size=UDim2.new(1,0,0,200),Parent=o.Holder},{r.Root})local s=i.GroupMotor.new{Scale=1,Offset=60}s:onStep(function(t)r.Root.Position=UDim2.new(t.Scale,t.Offset,0,0)end)j.AddSignal(r.CloseButton.MouseButton1Click,function()r:Close()end)function r.Open(t)local u=r.LabelHolder.AbsoluteSize.Y r.Holder.Size=UDim2.new(1,0,0,58+u)s:setGoal{Scale=l(0,{frequency=5}),Offset=l(0,{frequency=5})}end function r.Close(t)if not r.Closed then r.Closed=true task.spawn(function()s:setGoal{Scale=l(1,{frequency=5}),Offset=l(60,{frequency=5})}task.wait(0.4)if e(h).UseAcrylic then r.AcrylicPaint.Model:Destroy()end r.Holder:Destroy()end)end end r:Open()if q.Duration then task.delay(q.Duration,function()r:Close()end)end return r end return o end,
[13]=function()
local c,d,e,f,g=b(13)
local TweenService=game:GetService'TweenService'
local Root=d.Parent.Parent
local Creator=e(Root.Creator)
local New=Creator.New

return function(titleOrConfig,parent,collapsibleArg,defaultOpenArg)
    local title=''
    local collapsible=true
    local defaultOpen=true
    local icon=nil

    if type(titleOrConfig)=='table'then
        title=titleOrConfig.Title or titleOrConfig.Name or''
        if titleOrConfig.Collapsible~=nil then collapsible=titleOrConfig.Collapsible end
        if titleOrConfig.DefaultOpen~=nil then
            defaultOpen=titleOrConfig.DefaultOpen
        elseif titleOrConfig.Opened~=nil then
            defaultOpen=titleOrConfig.Opened
        end
        icon=titleOrConfig.Icon
    else
        title=tostring(titleOrConfig or'')
        if collapsibleArg~=nil then collapsible=collapsibleArg end
        if defaultOpenArg~=nil then defaultOpen=defaultOpenArg end
    end

    local resolvedIcon=e(Root):GetIcon(icon)
    local Sec={
        Title=title,
        Collapsible=(collapsible~=false),
        Opened=(defaultOpen~=false),
        ForceExpandSearch=false,
        UserVisible=true,
        SearchVisible=true,
        SearchItems={}
    }

    Sec.Layout=New('UIListLayout',{
        Padding=UDim.new(0,5),
        SortOrder=Enum.SortOrder.LayoutOrder
    })

    Sec.Container=New('Frame',{
        Size=UDim2.new(1,0,0,0),
        Position=UDim2.fromOffset(0,26),
        BackgroundTransparency=1,
        ClipsDescendants=true,
        Visible=Sec.Opened
    },{Sec.Layout})

    Sec.IconLabel=New('ImageLabel',{
        Image=resolvedIcon or'',
        Size=UDim2.fromOffset(16,16),
        Position=UDim2.new(0,0,0.5,0),
        AnchorPoint=Vector2.new(0,0.5),
        BackgroundTransparency=1,
        Visible=(resolvedIcon~=nil),
        ThemeTag={ImageColor3='Accent'}
    })

    Sec.TitleLabel=New('TextLabel',{
        RichText=true,
        Text=Sec.Title,
        TextTransparency=0,
        FontFace=Font.new('rbxassetid://12187365364',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal),
        TextSize=18,
        TextXAlignment='Left',
        TextYAlignment='Center',
        Size=UDim2.new(1,-28,0,18),
        Position=UDim2.fromOffset(resolvedIcon and 22 or 0,2),
        BackgroundTransparency=1,
        ThemeTag={TextColor3='Text'}
    })

    Sec.Chevron=New('ImageLabel',{
        Image='rbxassetid://10709790948',
        Size=UDim2.fromOffset(16,16),
        Position=UDim2.new(1,-4,0.5,0),
        AnchorPoint=Vector2.new(1,0.5),
        BackgroundTransparency=1,
        Visible=Sec.Collapsible,
        Rotation=Sec.Opened and 0 or -90,
        ThemeTag={ImageColor3='SubText'}
    })

    Sec.HeaderButton=New('TextButton',{
        Size=UDim2.new(1,0,0,22),
        Position=UDim2.fromOffset(0,0),
        BackgroundTransparency=1,
        Text='',
        AutoButtonColor=false
    },{
        Sec.IconLabel,
        Sec.TitleLabel,
        Sec.Chevron
    })

    Sec.Root=New('Frame',{
        BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,26),
        LayoutOrder=7,
        Parent=parent
    },{
        Sec.HeaderButton,
        Sec.Container
    })

    function Sec.UpdateSize(self)
        local vis=(Sec.UserVisible~=false)and(Sec.SearchVisible~=false)
        Sec.Root.Visible=vis
        if not vis then return end
        local isExpanded=Sec.Opened or Sec.ForceExpandSearch
        local contentY=Sec.Layout.AbsoluteContentSize.Y
        Sec.Container.Visible=isExpanded
        Sec.Container.Size=UDim2.new(1,0,0,isExpanded and contentY or 0)
        Sec.Root.Size=UDim2.new(1,0,0,isExpanded and(contentY+26)or 24)
        pcall(function()
            TweenService:Create(
                Sec.Chevron,
                TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
                {Rotation=isExpanded and 0 or -90}
            ):Play()
        end)
    end

    function Sec.SetOpened(self,state)
        Sec.Opened=(state~=false)
        Sec:UpdateSize()
    end

    function Sec.Toggle(self)
        Sec:SetOpened(not Sec.Opened)
    end

    function Sec.Expand(self)
        Sec:SetOpened(true)
    end

    function Sec.Collapse(self)
        Sec:SetOpened(false)
    end

    function Sec.SetTitle(self,newTitle)
        Sec.Title=tostring(newTitle or'')
        Sec.TitleLabel.Text=Sec.Title
    end

    function Sec.SetVisible(self,vis)
        Sec.UserVisible=(vis~=false)
        Sec:UpdateSize()
    end

    function Sec.Destroy(self)
        Sec.Root:Destroy()
    end

    Creator.AddSignal(Sec.HeaderButton.MouseButton1Click,function()
        if not Sec.Collapsible then return end
        if Sec.ForceExpandSearch then
            Sec.ForceExpandSearch=false
            Sec.Opened=false
            Sec:UpdateSize()
        else
            Sec:Toggle()
        end
    end)

    Creator.AddSignal(Sec.Layout:GetPropertyChangedSignal'AbsoluteContentSize',function()
        Sec:UpdateSize()
    end)

    Sec:UpdateSize()
    return Sec
end
end,
[14]=function()
local c,d,e,f,g=b(14)
local Root=d.Parent.Parent
local Flipper=e(Root.Packages.Flipper)
local Creator=e(Root.Creator)
local New=Creator.New
local Spring=Flipper.Spring.new
local Components=Root.Components

local TabManager={
    Window=nil,
    Tabs={},
    Containers={},
    SelectedTab=0,
    TabCount=0
}

function TabManager.Init(self,window)
    TabManager.Window=window
    TabManager.Tabs={}
    TabManager.Containers={}
    TabManager.SelectedTab=0
    TabManager.TabCount=0
    return TabManager
end

function TabManager.GetCurrentTabPos(self)
    if not TabManager.Window or not TabManager.Tabs[TabManager.SelectedTab]then return 0 end
    local holderY=TabManager.Window.TabHolder.AbsolutePosition.Y
    local tabY=TabManager.Tabs[TabManager.SelectedTab].Frame.AbsolutePosition.Y
    return tabY-holderY
end

function TabManager.New(self,title,icon,parentHolder)
    local Library=e(Root)
    local Window=TabManager.Window
    local ElementsMT=Library.Elements

    TabManager.TabCount=TabManager.TabCount+1
    local tabIdx=TabManager.TabCount
    local TabObj={
        Selected=false,
        Name=title,
        Type='Tab',
        SearchItems={},
        Sections={}
    }

    local resolvedIcon=Library:GetIcon(icon)

    TabObj.TitleLabel=New('TextLabel',{
        AnchorPoint=Vector2.new(0,0.5),
        Position=resolvedIcon and UDim2.new(0,30,0.5,0)or UDim2.new(0,12,0.5,0),
        Text=title,
        RichText=true,
        TextColor3=Color3.fromRGB(255,255,255),
        TextTransparency=0,
        FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Regular,Enum.FontStyle.Normal),
        TextSize=12,
        TextXAlignment='Left',
        TextYAlignment='Center',
        Size=UDim2.new(1,-12,1,0),
        BackgroundTransparency=1,
        ThemeTag={TextColor3='Text'}
    })

    TabObj.IconImage=New('ImageLabel',{
        AnchorPoint=Vector2.new(0,0.5),
        Size=UDim2.fromOffset(16,16),
        Position=UDim2.new(0,8,0.5,0),
        BackgroundTransparency=1,
        Image=resolvedIcon,
        ThemeTag={ImageColor3='Text'}
    })

    TabObj.Frame=New('TextButton',{
        Size=UDim2.new(1,0,0,34),
        BackgroundTransparency=1,
        Parent=parentHolder,
        ThemeTag={BackgroundColor3='Tab'}
    },{
        New('UICorner',{CornerRadius=UDim.new(0,6)}),
        TabObj.TitleLabel,
        TabObj.IconImage
    })

    local listLayout=New('UIListLayout',{
        Padding=UDim.new(0,5),
        SortOrder=Enum.SortOrder.LayoutOrder
    })

    TabObj.ContainerFrame=New('ScrollingFrame',{
        Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,
        Parent=Window.ContainerHolder,
        Visible=false,
        BottomImage='rbxassetid://6889812791',
        MidImage='rbxassetid://6889812721',
        TopImage='rbxassetid://6276641225',
        ScrollBarImageColor3=Color3.fromRGB(255,255,255),
        ScrollBarImageTransparency=0.95,
        ScrollBarThickness=3,
        BorderSizePixel=0,
        CanvasSize=UDim2.fromScale(0,0),
        ScrollingDirection=Enum.ScrollingDirection.Y
    },{
        listLayout,
        New('UIPadding',{
            PaddingRight=UDim.new(0,10),
            PaddingLeft=UDim.new(0,1),
            PaddingTop=UDim.new(0,1),
            PaddingBottom=UDim.new(0,1)
        })
    })

    Creator.AddSignal(listLayout:GetPropertyChangedSignal'AbsoluteContentSize',function()
        TabObj.ContainerFrame.CanvasSize=UDim2.new(0,0,0,listLayout.AbsoluteContentSize.Y+2)
    end)

    TabObj.Motor,TabObj.SetTransparency=Creator.SpringMotor(1,TabObj.Frame,'BackgroundTransparency')
    Creator.AddSignal(TabObj.Frame.MouseEnter,function()
        TabObj.SetTransparency(TabObj.Selected and 0.85 or 0.89)
    end)
    Creator.AddSignal(TabObj.Frame.MouseLeave,function()
        TabObj.SetTransparency(TabObj.Selected and 0.89 or 1)
    end)
    Creator.AddSignal(TabObj.Frame.MouseButton1Down,function()
        TabObj.SetTransparency(0.92)
    end)
    Creator.AddSignal(TabObj.Frame.MouseButton1Up,function()
        TabObj.SetTransparency(TabObj.Selected and 0.85 or 0.89)
    end)
    Creator.AddSignal(TabObj.Frame.MouseButton1Click,function()
        TabManager:SelectTab(tabIdx)
    end)

    TabManager.Containers[tabIdx]=TabObj.ContainerFrame
    TabManager.Tabs[tabIdx]=TabObj
    TabObj.Container=TabObj.ContainerFrame
    TabObj.ScrollFrame=TabObj.Container

    function TabObj.RegisterSearchItem(self,elemComp)
        table.insert(TabObj.SearchItems,elemComp)
    end

    function TabObj.AddSection(self,titleOrConfig,collapsible,defaultOpen)
        local SecComp=e(Components.Section)(titleOrConfig,TabObj.Container,collapsible,defaultOpen)
        local SectionWrapper={
            Type='Section',
            Container=SecComp.Container,
            ScrollFrame=TabObj.Container,
            SectionComp=SecComp,
            SearchItems=SecComp.SearchItems,
            SetOpened=function(_,st)return SecComp:SetOpened(st)end,
            Toggle=function(_)return SecComp:Toggle()end,
            Expand=function(_)return SecComp:Expand()end,
            Collapse=function(_)return SecComp:Collapse()end,
            SetTitle=function(_,t)return SecComp:SetTitle(t)end,
            SetVisible=function(_,v)return SecComp:SetVisible(v)end,
            Destroy=function(_)return SecComp:Destroy()end,
            RegisterSearchItem=function(_,elemComp)
                table.insert(SecComp.SearchItems,elemComp)
                elemComp.OnVisibilityChanged=function()
                    SecComp:UpdateSize()
                end
            end
        }
        table.insert(TabObj.Sections,SecComp)
        setmetatable(SectionWrapper,ElementsMT)
        return SectionWrapper
    end

    setmetatable(TabObj,ElementsMT)
    return TabObj
end

function TabManager.SelectTab(self,tabIdx)
    local Window=TabManager.Window
    if not TabManager.Tabs[tabIdx]then return end
    pcall(function()e(Root):CloseAllDropdowns()end)
    TabManager.SelectedTab=tabIdx
    for _,tab in next,TabManager.Tabs do
        tab.SetTransparency(1)
        tab.Selected=false
    end
    TabManager.Tabs[tabIdx].SetTransparency(0.89)
    TabManager.Tabs[tabIdx].Selected=true
    Window.TabDisplay.Text=TabManager.Tabs[tabIdx].Name
    Window.SelectorPosMotor:setGoal(Spring(TabManager:GetCurrentTabPos(),{frequency=6}))
    task.spawn(function()
        Window.ContainerPosMotor:setGoal(Spring(110,{frequency=10}))
        Window.ContainerBackMotor:setGoal(Spring(1,{frequency=10}))
        task.wait(0.15)
        for _,cont in next,TabManager.Containers do
            cont.Visible=false
        end
        if TabManager.Containers[tabIdx]then
            TabManager.Containers[tabIdx].Visible=true
        end
        if TabManager.Tabs[tabIdx]and TabManager.Tabs[tabIdx].Sections then
            for _,sec in ipairs(TabManager.Tabs[tabIdx].Sections)do
                sec:UpdateSize()
            end
        end
        Window.ContainerPosMotor:setGoal(Spring(94,{frequency=5}))
        Window.ContainerBackMotor:setGoal(Spring(0,{frequency=8}))
    end)
end

function TabManager.FilterTabs(self,rawQuery)
    local query=(rawQuery or''):lower():gsub('^%s+',''):gsub('%s+$','')
    if query==''then
        for _,tab in next,TabManager.Tabs do
            tab.TitleLabel.TextTransparency=0
            tab.IconImage.ImageTransparency=0
            for _,item in ipairs(tab.SearchItems)do
                item.SearchVisible=true
                item:UpdateVisibility()
            end
            for _,sec in ipairs(tab.Sections)do
                sec.ForceExpandSearch=false
                sec.SearchVisible=true
                for _,item in ipairs(sec.SearchItems)do
                    item.SearchVisible=true
                    item:UpdateVisibility()
                end
                sec:UpdateSize()
            end
        end
        return
    end

    local firstMatchTab=nil
    local selectedTabMatches=false

    for idx,tab in ipairs(TabManager.Tabs)do
        local tabMatched=false

        for _,item in ipairs(tab.SearchItems)do
            local txt=item.GetSearchText and item:GetSearchText()or''
            local m=(txt:find(query,1,true)~=nil)
            item.SearchVisible=m
            item:UpdateVisibility()
            if m and item.UserVisible~=false then
                tabMatched=true
            end
        end

        for _,sec in ipairs(tab.Sections)do
            local secTitleClean=(sec.Title or''):gsub('<[^>]+>',''):lower()
            local secSelfMatched=(secTitleClean:find(query,1,true)~=nil)
            local childMatches=0

            for _,item in ipairs(sec.SearchItems)do
                local m=secSelfMatched
                if not m then
                    local txt=item.GetSearchText and item:GetSearchText()or''
                    m=(txt:find(query,1,true)~=nil)
                end
                item.SearchVisible=m
                item:UpdateVisibility()
                if m and item.UserVisible~=false then
                    childMatches=childMatches+1
                end
            end

            if secSelfMatched or childMatches>0 then
                sec.SearchVisible=true
                sec.ForceExpandSearch=true
                tabMatched=true
            else
                sec.SearchVisible=false
                sec.ForceExpandSearch=false
            end
            sec:UpdateSize()
        end

        tab.TitleLabel.TextTransparency=tabMatched and 0 or 0.55
        tab.IconImage.ImageTransparency=tabMatched and 0 or 0.55

        if tabMatched then
            if not firstMatchTab then firstMatchTab=idx end
            if idx==TabManager.SelectedTab then selectedTabMatches=true end
        end
    end

    if not selectedTabMatches and firstMatchTab and firstMatchTab~=TabManager.SelectedTab then
        TabManager:SelectTab(firstMatchTab)
    end
end

return TabManager
end,
[15]=function()local c,d,e,f,g=b(15)local h,i=game:GetService'TextService',d.Parent.Parent local j,k=e(i.Packages.Flipper),e(i.Creator)local l=k.New return function(m,n)n=n or false local o={}o.Input=l('TextBox',{FontFace=Font.new'rbxasset://fonts/families/GothamSSm.json',TextColor3=Color3.fromRGB(200,200,200),TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,BackgroundColor3=Color3.fromRGB(255,255,255),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Position=UDim2.fromOffset(10,0),ThemeTag={TextColor3='Text',PlaceholderColor3='SubText'}})o.Container=l('Frame',{BackgroundTransparency=1,ClipsDescendants=true,Position=UDim2.new(0,6,0,0),Size=UDim2.new(1,-12,1,0)},{o.Input})o.Indicator=l('Frame',{Size=UDim2.new(1,-4,0,1),Position=UDim2.new(0,2,1,0),AnchorPoint=Vector2.new(0,1),BackgroundTransparency=n and 0.5 or 0,ThemeTag={BackgroundColor3=n and'InputIndicator'or'DialogInputLine'}})o.Frame=l('Frame',{Size=UDim2.new(0,0,0,30),BackgroundTransparency=n and 0.9 or 0,Parent=m,ThemeTag={BackgroundColor3=n and'Input'or'DialogInput'}},{l('UICorner',{CornerRadius=UDim.new(0,4)}),l('UIStroke',{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Transparency=n and 0.5 or 0.65,ThemeTag={Color=n and'InElementBorder'or'DialogButtonBorder'}}),o.Indicator,o.Container})local p=function()local p,q=2,o.Container.AbsoluteSize.X if not o.Input:IsFocused()or o.Input.TextBounds.X<=q-2*p then o.Input.Position=UDim2.new(0,p,0,0)else local r=o.Input.CursorPosition if r~=-1 then local s=string.sub(o.Input.Text,1,r-1)local t=h:GetTextSize(s,o.Input.TextSize,o.Input.Font,Vector2.new(math.huge,math.huge)).X local u=o.Input.Position.X.Offset+t if u<p then o.Input.Position=UDim2.fromOffset(p-t,0)elseif u>q-p-1 then o.Input.Position=UDim2.fromOffset(q-t-p-1,0)end end end end task.spawn(p)k.AddSignal(o.Input:GetPropertyChangedSignal'Text',p)k.AddSignal(o.Input:GetPropertyChangedSignal'CursorPosition',p)k.AddSignal(o.Input.Focused,function()p()o.Indicator.Size=UDim2.new(1,-2,0,2)o.Indicator.Position=UDim2.new(0,1,1,0)o.Indicator.BackgroundTransparency=0 k.OverrideTag(o.Frame,{BackgroundColor3=n and'InputFocused'or'DialogHolder'})k.OverrideTag(o.Indicator,{BackgroundColor3='Accent'})end)k.AddSignal(o.Input.FocusLost,function()p()o.Indicator.Size=UDim2.new(1,-4,0,1)o.Indicator.Position=UDim2.new(0,2,1,0)o.Indicator.BackgroundTransparency=0.5 k.OverrideTag(o.Frame,{BackgroundColor3=n and'Input'or'DialogInput'})k.OverrideTag(o.Indicator,{BackgroundColor3=n and'InputIndicator'or'DialogInputLine'})end)return o end end,
[16]=function()local c,d,e,f,g=b(16)local h,i=d.Parent.Parent,e(d.Parent.Assets)local j,k=e(h.Creator),e(h.Packages.Flipper)local l,m=j.New,j.AddSignal return function(n)local o,p,q={},e(h),function(o,p,q,r)local s={Callback=r or function()end}s.Frame=l('TextButton',{Size=UDim2.new(0,34,1,-8),AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,Parent=q,Position=p,Text='',ThemeTag={BackgroundColor3='Text'}},{l('UICorner',{CornerRadius=UDim.new(0,7)}),l('ImageLabel',{Image=o,Size=UDim2.fromOffset(16,16),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Name='Icon',ThemeTag={ImageColor3='Text'}})})local t,u=j.SpringMotor(1,s.Frame,'BackgroundTransparency')m(s.Frame.MouseEnter,function()u(0.94)end)m(s.Frame.MouseLeave,function()u(1,true)end)m(s.Frame.MouseButton1Down,function()u(0.96)end)m(s.Frame.MouseButton1Up,function()u(0.94)end)m(s.Frame.MouseButton1Click,s.Callback)s.SetCallback=function(v)s.Callback=v end return s end o.Frame=l('Frame',{Size=UDim2.new(1,0,0,42),BackgroundTransparency=1,Parent=n.Parent},{l('Frame',{Size=UDim2.new(1,-16,1,0),Position=UDim2.new(0,16,0,0),BackgroundTransparency=1},{l('UIListLayout',{Padding=UDim.new(0,5),FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder}),l('TextLabel',{RichText=true,Text=n.Title,FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Regular,Enum.FontStyle.Normal),TextSize=12,TextXAlignment='Left',TextYAlignment='Center',Size=UDim2.fromScale(0,1),AutomaticSize=Enum.AutomaticSize.X,BackgroundTransparency=1,ThemeTag={TextColor3='Text'}}),l('TextLabel',{RichText=true,Text=n.SubTitle,TextTransparency=0.4,FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Regular,Enum.FontStyle.Normal),TextSize=12,TextXAlignment='Left',TextYAlignment='Center',Size=UDim2.fromScale(0,1),AutomaticSize=Enum.AutomaticSize.X,BackgroundTransparency=1,ThemeTag={TextColor3='Text'}})}),l('Frame',{BackgroundTransparency=0.5,Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,0),ThemeTag={BackgroundColor3='TitleBarLine'}})})o.CloseButton=q(i.Close,UDim2.new(1,-4,0,4),o.Frame,function()p.Window:Dialog{Title='Close',Content='Are you sure you want to unload the interface?',Buttons={{Title='Yes',Callback=function()p:Destroy()end},{Title='No'}}}end)o.MaxButton=q(i.Max,UDim2.new(1,-40,0,4),o.Frame,function()n.Window.Maximize(not n.Window.Maximized)end)o.MinButton=q(i.Min,UDim2.new(1,-80,0,4),o.Frame,function()p.Window:Minimize()end)return o end end,
[17]=function()
local c,d,e,f,g=b(17)
local UserInputService=game:GetService'UserInputService'
local Mouse=game:GetService'Players'.LocalPlayer:GetMouse()
local Camera=game:GetService'Workspace'.CurrentCamera
local Root=d.Parent.Parent
local Flipper=e(Root.Packages.Flipper)
local Creator=e(Root.Creator)
local Acrylic=e(Root.Acrylic)
local Assets=e(d.Parent.Assets)
local Components=d.Parent
local Spring=Flipper.Spring.new
local Instant=Flipper.Instant.new
local New=Creator.New

return function(config)
    local Library=e(Root)
    local Window={
        Minimized=false,
        Maximized=false,
        Size=config.Size,
        CurrentPos=0,
        Position=UDim2.fromOffset(
            Camera.ViewportSize.X/2-config.Size.X.Offset/2,
            Camera.ViewportSize.Y/2-config.Size.Y.Offset/2
        )
    }

    local dragging,dragInput,dragStart,startPos=false,nil,nil,nil
    local resizing,resizeStart=false,nil
    local minimizeNotified=false

    Window.AcrylicPaint=Acrylic.AcrylicPaint()

    local SelectorIndicator=New('Frame',{
        Size=UDim2.fromOffset(4,0),
        BackgroundColor3=Color3.fromRGB(76,194,255),
        Position=UDim2.fromOffset(0,17),
        AnchorPoint=Vector2.new(0,0.5),
        ThemeTag={BackgroundColor3='Accent'}
    },{New('UICorner',{CornerRadius=UDim.new(0,2)})})

    local ResizeHandle=New('Frame',{
        Size=UDim2.fromOffset(20,20),
        BackgroundTransparency=1,
        Position=UDim2.new(1,-20,1,-20)
    })

    Window.TabHolder=New('ScrollingFrame',{
        Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,
        ScrollBarImageTransparency=1,
        ScrollBarThickness=0,
        BorderSizePixel=0,
        CanvasSize=UDim2.fromScale(0,0),
        ScrollingDirection=Enum.ScrollingDirection.Y
    },{New('UIListLayout',{Padding=UDim.new(0,4)})})

    local SidebarFrame=New('Frame',{
        Size=UDim2.new(0,config.TabWidth,1,-66),
        Position=UDim2.new(0,12,0,54),
        BackgroundTransparency=1,
        ClipsDescendants=true
    },{Window.TabHolder,SelectorIndicator})

    Window.TabDisplay=New('TextLabel',{
        RichText=true,
        Text='Tab',
        TextTransparency=0,
        FontFace=Font.new('rbxassetid://12187365364',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal),
        TextSize=28,
        TextXAlignment='Left',
        TextYAlignment='Center',
        Size=UDim2.new(1,-(config.TabWidth+226),0,28),
        Position=UDim2.fromOffset(config.TabWidth+26,56),
        BackgroundTransparency=1,
        TextTruncate=Enum.TextTruncate.AtEnd,
        ThemeTag={TextColor3='Text'}
    })

    Window.SearchBox=New('TextBox',{
        FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Regular,Enum.FontStyle.Normal),
        Text='',
        PlaceholderText='Search settings...',
        TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.new(1,-48,1,0),
        Position=UDim2.fromOffset(26,0),
        BackgroundTransparency=1,
        ClearTextOnFocus=false,
        ThemeTag={TextColor3='Text',PlaceholderColor3='SubText'}
    })

    Window.SearchClearBtn=New('TextButton',{
        Size=UDim2.fromOffset(16,16),
        Position=UDim2.new(1,-6,0.5,0),
        AnchorPoint=Vector2.new(1,0.5),
        BackgroundTransparency=1,
        Text='',
        Visible=false
    },{
        New('ImageLabel',{
            Image='rbxassetid://10747384394',
            Size=UDim2.fromOffset(12,12),
            Position=UDim2.fromScale(0.5,0.5),
            AnchorPoint=Vector2.new(0.5,0.5),
            BackgroundTransparency=1,
            ThemeTag={ImageColor3='SubText'}
        })
    })

    local SearchStroke=New('UIStroke',{
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
        Thickness=1,
        Transparency=0.5,
        ThemeTag={Color='InElementBorder'}
    })

    Window.SearchFrame=New('Frame',{
        Size=UDim2.fromOffset(180,28),
        Position=UDim2.new(1,-16,0,56),
        AnchorPoint=Vector2.new(1,0),
        BackgroundTransparency=0.88,
        Visible=(config.Search~=false),
        ThemeTag={BackgroundColor3='Input'}
    },{
        New('UICorner',{CornerRadius=UDim.new(0,6)}),
        SearchStroke,
        New('ImageLabel',{
            Image='rbxassetid://10734943674',
            Size=UDim2.fromOffset(13,13),
            Position=UDim2.new(0,8,0.5,0),
            AnchorPoint=Vector2.new(0,0.5),
            BackgroundTransparency=1,
            ThemeTag={ImageColor3='SubText'}
        }),
        Window.SearchBox,
        Window.SearchClearBtn
    })

    Window.ContainerHolder=New('CanvasGroup',{
        Size=UDim2.new(1,-config.TabWidth-32,1,-102),
        Position=UDim2.fromOffset(config.TabWidth+26,90),
        BackgroundTransparency=1
    })

    Window.Root=New('Frame',{
        BackgroundTransparency=1,
        Size=Window.Size,
        Position=Window.Position,
        Parent=config.Parent
    },{
        Window.AcrylicPaint.Frame,
        Window.TabDisplay,
        Window.SearchFrame,
        Window.ContainerHolder,
        SidebarFrame,
        ResizeHandle
    })

    Window.TitleBar=e(d.Parent.TitleBar){
        Title=config.Title,
        SubTitle=config.SubTitle,
        Parent=Window.Root,
        Window=Window
    }

    if Library.UseAcrylic then
        Window.AcrylicPaint.AddParent(Window.Root)
    end

    local SizeMotor=Flipper.GroupMotor.new{X=Window.Size.X.Offset,Y=Window.Size.Y.Offset}
    local PosMotor=Flipper.GroupMotor.new{X=Window.Position.X.Offset,Y=Window.Position.Y.Offset}
    Window.SelectorPosMotor=Flipper.SingleMotor.new(17)
    Window.SelectorSizeMotor=Flipper.SingleMotor.new(0)
    Window.ContainerBackMotor=Flipper.SingleMotor.new(0)
    Window.ContainerPosMotor=Flipper.SingleMotor.new(94)

    SizeMotor:onStep(function(val)
        Window.Root.Size=UDim2.new(0,val.X,0,val.Y)
    end)
    PosMotor:onStep(function(val)
        Window.Root.Position=UDim2.new(0,val.X,0,val.Y)
    end)

    local lastSelectorPos,lastSelectorTime=0,0
    Window.SelectorPosMotor:onStep(function(val)
        SelectorIndicator.Position=UDim2.new(0,0,0,val+17)
        local now=tick()
        local dt=now-lastSelectorTime
        if lastSelectorPos~=nil then
            Window.SelectorSizeMotor:setGoal(Spring((math.abs(val-lastSelectorPos)/(math.max(dt,0.001)*60))+16))
            lastSelectorPos=val
        end
        lastSelectorTime=now
    end)
    Window.SelectorSizeMotor:onStep(function(val)
        SelectorIndicator.Size=UDim2.new(0,4,0,val)
    end)
    Window.ContainerBackMotor:onStep(function(val)
        Window.ContainerHolder.GroupTransparency=val
    end)
    Window.ContainerPosMotor:onStep(function(val)
        Window.ContainerHolder.Position=UDim2.fromOffset(config.TabWidth+26,val)
    end)

    local oldWidth,oldHeight
    Window.Maximize=function(state,noPosAnim,instant)
        Window.Maximized=state
        Window.TitleBar.MaxButton.Frame.Icon.Image=state and Assets.Restore or Assets.Max
        if state then
            oldWidth=Window.Size.X.Offset
            oldHeight=Window.Size.Y.Offset
        end
        local targetW=state and Camera.ViewportSize.X or oldWidth
        local targetH=state and Camera.ViewportSize.Y or oldHeight
        SizeMotor:setGoal{
            X=Flipper[instant and'Instant'or'Spring'].new(targetW,{frequency=6}),
            Y=Flipper[instant and'Instant'or'Spring'].new(targetH,{frequency=6})
        }
        Window.Size=UDim2.fromOffset(targetW,targetH)
        if not noPosAnim then
            PosMotor:setGoal{
                X=Spring(state and 0 or Window.Position.X.Offset,{frequency=6}),
                Y=Spring(state and 0 or Window.Position.Y.Offset,{frequency=6})
            }
        end
    end

    Creator.AddSignal(Window.TitleBar.Frame.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true
            dragStart=input.Position
            startPos=Window.Root.Position
            if Window.Maximized then
                startPos=UDim2.fromOffset(
                    Mouse.X-(Mouse.X*((oldWidth-100)/Window.Root.AbsoluteSize.X)),
                    Mouse.Y-(Mouse.Y*(oldHeight/Window.Root.AbsoluteSize.Y))
                )
            end
            input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then
                    dragging=false
                end
            end)
        end
    end)

    Creator.AddSignal(Window.TitleBar.Frame.InputChanged,function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
            dragInput=input
        end
    end)

    Creator.AddSignal(ResizeHandle.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            resizing=true
            resizeStart=input.Position
        end
    end)

    Creator.AddSignal(UserInputService.InputChanged,function(input)
        if input==dragInput and dragging then
            local delta=input.Position-dragStart
            Window.Position=UDim2.fromOffset(startPos.X.Offset+delta.X,startPos.Y.Offset+delta.Y)
            PosMotor:setGoal{X=Instant(Window.Position.X.Offset),Y=Instant(Window.Position.Y.Offset)}
            if Window.Maximized then
                Window.Maximize(false,true,true)
            end
        end
        if(input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)and resizing then
            local delta=input.Position-resizeStart
            local origSize=Window.Size
            local newVec=Vector3.new(origSize.X.Offset,origSize.Y.Offset,0)+Vector3.new(1,1,0)*delta
            local clamped=Vector2.new(math.clamp(newVec.X,470,2048),math.clamp(newVec.Y,380,2048))
            SizeMotor:setGoal{X=Instant(clamped.X),Y=Instant(clamped.Y)}
        end
    end)

    Creator.AddSignal(UserInputService.InputEnded,function(input)
        if resizing==true or input.UserInputType==Enum.UserInputType.Touch then
            resizing=false
            Window.Size=UDim2.fromOffset(SizeMotor:getValue().X,SizeMotor:getValue().Y)
        end
    end)

    Creator.AddSignal(Window.TabHolder.UIListLayout:GetPropertyChangedSignal'AbsoluteContentSize',function()
        Window.TabHolder.CanvasSize=UDim2.new(0,0,0,Window.TabHolder.UIListLayout.AbsoluteContentSize.Y)
    end)

    Creator.AddSignal(UserInputService.InputBegan,function(input)
        if type(Library.MinimizeKeybind)=='table'and Library.MinimizeKeybind.Type=='Keybind'and not UserInputService:GetFocusedTextBox()then
            if input.KeyCode.Name==Library.MinimizeKeybind.Value then
                Window:Minimize()
            end
        elseif input.KeyCode==Library.MinimizeKey and not UserInputService:GetFocusedTextBox()then
            Window:Minimize()
        elseif input.KeyCode==Enum.KeyCode.F and(UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)or UserInputService:IsKeyDown(Enum.KeyCode.RightControl))and not UserInputService:GetFocusedTextBox()and not Window.Minimized and Window.SearchFrame.Visible then
            Window.SearchBox:CaptureFocus()
        end
    end)

    function Window.Minimize(self)
        Window.Minimized=not Window.Minimized
        Window.Root.Visible=not Window.Minimized
        Library:HideTooltip()
        Library:CloseAllDropdowns()
        if not minimizeNotified then
            minimizeNotified=true
            local keyName=Library.MinimizeKeybind and Library.MinimizeKeybind.Value or Library.MinimizeKey.Name
            Library:Notify{Title='Interface',Content='Press '..keyName..' to toggle the interface.',Duration=6}
        end
    end

    function Window.Destroy(self)
        Library:HideTooltip()
        Library:CloseAllDropdowns()
        if Library.UseAcrylic then
            Window.AcrylicPaint.Model:Destroy()
        end
        Window.Root:Destroy()
    end

    local DialogModule=e(Components.Dialog):Init(Window)
    function Window.Dialog(self,dialogCfg)
        local dlg=DialogModule:Create()
        dlg.Title.Text=dialogCfg.Title
        local contentLbl=New('TextLabel',{
            FontFace=Font.new'rbxasset://fonts/families/GothamSSm.json',
            Text=dialogCfg.Content,
            TextColor3=Color3.fromRGB(240,240,240),
            TextSize=14,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextYAlignment=Enum.TextYAlignment.Top,
            Size=UDim2.new(1,-40,1,0),
            Position=UDim2.fromOffset(20,60),
            BackgroundTransparency=1,
            Parent=dlg.Root,
            ClipsDescendants=false,
            ThemeTag={TextColor3='Text'}
        })
        New('UISizeConstraint',{MinSize=Vector2.new(300,165),MaxSize=Vector2.new(620,math.huge),Parent=dlg.Root})
        dlg.Root.Size=UDim2.fromOffset(contentLbl.TextBounds.X+40,165)
        if contentLbl.TextBounds.X+40>Window.Size.X.Offset-120 then
            dlg.Root.Size=UDim2.fromOffset(Window.Size.X.Offset-120,165)
            contentLbl.TextWrapped=true
            dlg.Root.Size=UDim2.fromOffset(Window.Size.X.Offset-120,contentLbl.TextBounds.Y+150)
        end
        for _,btn in next,dialogCfg.Buttons do
            dlg:Button(btn.Title,btn.Callback)
        end
        dlg:Open()
    end

    local TabManager=e(Components.Tab):Init(Window)
    function Window.AddTab(self,tabCfg)
        return TabManager:New(tabCfg.Title,tabCfg.Icon,Window.TabHolder)
    end
    function Window.SelectTab(self,idx)
        TabManager:SelectTab(idx or 1)
    end
    function Window.SetSearch(self,query)
        query=tostring(query or'')
        Window.SearchBox.Text=query
        Window.SearchClearBtn.Visible=(query~='')
        TabManager:FilterTabs(query)
    end
    Window.Search=Window.SetSearch

    Creator.AddSignal(Window.SearchBox.Focused,function()
        Creator.OverrideTag(Window.SearchFrame,{BackgroundColor3='InputFocused'})
        Creator.OverrideTag(SearchStroke,{Color='Accent'})
        SearchStroke.Transparency=0.15
    end)

    Creator.AddSignal(Window.SearchBox.FocusLost,function()
        Creator.OverrideTag(Window.SearchFrame,{BackgroundColor3='Input'})
        Creator.OverrideTag(SearchStroke,{Color='InElementBorder'})
        SearchStroke.Transparency=0.5
    end)

    Creator.AddSignal(Window.SearchBox:GetPropertyChangedSignal'Text',function()
        local txt=Window.SearchBox.Text or''
        Window.SearchClearBtn.Visible=(txt~='')
        TabManager:FilterTabs(txt)
    end)

    Creator.AddSignal(Window.SearchClearBtn.MouseButton1Click,function()
        Window.SearchBox.Text=''
    end)

    Creator.AddSignal(Window.TabHolder:GetPropertyChangedSignal'CanvasPosition',function()
        lastSelectorPos=TabManager:GetCurrentTabPos()+16
        lastSelectorTime=0
        Window.SelectorPosMotor:setGoal(Instant(TabManager:GetCurrentTabPos()))
    end)

    return Window
end
end,
[18]=function()
local c,d,e,f,g=b(18)
local Root=d.Parent
local Themes=e(Root.Themes)
local Flipper=e(Root.Packages.Flipper)

local Creator={
    Registry={},
    Signals={},
    TransparencyMotors={},
    DefaultProperties={
        ScreenGui={ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},
        Frame={BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0,0,0),BorderSizePixel=0},
        ScrollingFrame={BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0,0,0),ScrollBarImageColor3=Color3.new(0,0,0)},
        TextLabel={BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0,0,0),Font=Enum.Font.SourceSans,Text='',TextColor3=Color3.new(0,0,0),BackgroundTransparency=1,TextSize=14},
        TextButton={BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0,0,0),AutoButtonColor=false,Font=Enum.Font.SourceSans,Text='',TextColor3=Color3.new(0,0,0),TextSize=14},
        TextBox={BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0,0,0),ClearTextOnFocus=false,Font=Enum.Font.SourceSans,Text='',TextColor3=Color3.new(0,0,0),TextSize=14},
        ImageLabel={BackgroundTransparency=1,BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0,0,0),BorderSizePixel=0},
        ImageButton={BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0,0,0),AutoButtonColor=false},
        CanvasGroup={BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0,0,0),BorderSizePixel=0}
    }
}

function Creator.AddSignal(signal,callback)
    local conn=signal:Connect(function(...)
        if e(Root).Unloaded then return end
        if setthreadidentity then pcall(setthreadidentity,8)end
        return callback(...)
    end)
    table.insert(Creator.Signals,conn)
    return conn
end

function Creator.Disconnect()
    for idx=#Creator.Signals,1,-1 do
        local conn=table.remove(Creator.Signals,idx)
        pcall(function()conn:Disconnect()end)
    end
    table.clear(Creator.Registry)
    table.clear(Creator.TransparencyMotors)
end

function Creator.GetThemeProperty(prop)
    local activeTheme=Themes[e(Root).Theme]
    if activeTheme and activeTheme[prop]~=nil then
        return activeTheme[prop]
    end
    return Themes.Dark[prop]
end

local function ApplyObjectTheme(obj,props)
    for propName,themeKey in next,props do
        pcall(function()
            obj[propName]=Creator.GetThemeProperty(themeKey)
        end)
    end
end

function Creator.UpdateTheme()
    for obj,entry in next,Creator.Registry do
        if obj and obj.Parent~=nil then
            ApplyObjectTheme(obj,entry.Properties)
        end
    end
    local elemTrans=Creator.GetThemeProperty'ElementTransparency'
    for _,motor in next,Creator.TransparencyMotors do
        pcall(function()
            motor:setGoal(Flipper.Instant.new(elemTrans))
        end)
    end
end

function Creator.AddThemeObject(obj,props)
    Creator.Registry[obj]={Object=obj,Properties=props}
    ApplyObjectTheme(obj,props)
    return obj
end

function Creator.OverrideTag(obj,props)
    if Creator.Registry[obj]then
        Creator.Registry[obj].Properties=props
    else
        Creator.Registry[obj]={Object=obj,Properties=props}
    end
    ApplyObjectTheme(obj,props)
end

function Creator.New(className,props,children)
    local inst=Instance.new(className)
    for k,v in next,Creator.DefaultProperties[className]or{}do
        inst[k]=v
    end
    for k,v in next,props or{}do
        if k~='ThemeTag'then
            inst[k]=v
        end
    end
    for _,child in next,children or{}do
        child.Parent=inst
    end
    if props and props.ThemeTag then
        Creator.AddThemeObject(inst,props.ThemeTag)
    end
    return inst
end

function Creator.SpringMotor(initial,instance,prop,ignoreDialogCheck,resetOnThemeChange)
    ignoreDialogCheck=ignoreDialogCheck or false
    resetOnThemeChange=resetOnThemeChange or false
    local motor=Flipper.SingleMotor.new(initial)
    motor:onStep(function(val)
        if e(Root).Unloaded then
            motor:stop()
            return
        end
        pcall(function()
            if setthreadidentity then setthreadidentity(8)end
            instance[prop]=val
        end)
    end)
    if resetOnThemeChange then
        table.insert(Creator.TransparencyMotors,motor)
    end
    local setGoal=function(targetVal,force)
        force=force or false
        if not ignoreDialogCheck and not force then
            if prop=='BackgroundTransparency'and e(Root).DialogOpen then
                return
            end
        end
        motor:setGoal(Flipper.Spring.new(targetVal,{frequency=8}))
    end
    return motor,setGoal
end

function Creator.ApplyElementAPI(wrapper,elemComp,config,context)
    config=config or{}
    if wrapper~=elemComp then
        wrapper.ElementFrame=elemComp
        wrapper.Frame=elemComp.Frame
        wrapper.SetTitle=function(_,t)return elemComp:SetTitle(t)end
        wrapper.SetDesc=function(_,d)return elemComp:SetDesc(d)end
        wrapper.SetTooltip=function(_,tt)return elemComp:SetTooltip(tt)end
        wrapper.SetLocked=function(_,l,r)return elemComp:SetLocked(l,r)end
        wrapper.SetDisabled=function(_,l,r)return elemComp:SetLocked(l,r)end
        wrapper.Lock=function(_,r)return elemComp:SetLocked(true,r)end
        wrapper.Unlock=function(_)return elemComp:SetLocked(false)end
        wrapper.IsLocked=function(_)return elemComp.Locked end
        wrapper.SetVisible=function(_,v)return elemComp:SetVisible(v)end
        wrapper.UpdateVisibility=function(_)return elemComp:UpdateVisibility()end
    end
    if config.Tooltip then
        elemComp:SetTooltip(config.Tooltip)
    end
    if config.Locked or config.Disabled then
        elemComp:SetLocked(true,config.LockReason or config.LockedText or config.DisabledReason)
    end
    if config.Visible==false then
        elemComp:SetVisible(false)
    end
    if context and context.RegisterSearchItem then
        context:RegisterSearchItem(elemComp)
    end
    return wrapper
end

return Creator
end,
[19]=function()local c,d,e,f,g=b(19)local h={}for i,j in next,d:GetChildren()do table.insert(h,e(j))end return h end,
[20]=function()
local c,d,e,f,g=b(20)
local Root=d.Parent.Parent
local Creator=e(Root.Creator)
local New=Creator.New
local Components=Root.Components
local ButtonElem={}
ButtonElem.__index=ButtonElem
ButtonElem.__type='Button'

function ButtonElem.New(self,config)
    assert(config.Title,'Button - Missing Title')
    config.Callback=config.Callback or function()end
    local elem=e(Components.Element)(config.Title,config.Description,self.Container,true)
    New('ImageLabel',{
        Image='rbxassetid://10709791437',
        Size=UDim2.fromOffset(16,16),
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-10,0.5,0),
        BackgroundTransparency=1,
        Parent=elem.Frame,
        ThemeTag={ImageColor3='Text'}
    })
    Creator.AddSignal(elem.Frame.MouseButton1Click,function()
        if elem.Locked then return end
        self.Library:SafeCallback(config.Callback)
    end)
    Creator.ApplyElementAPI(elem,elem,config,self.Context)
    return elem
end

return ButtonElem
end,
[21]=function()local c,d,e,f,g=b(21)local h,i,j,k=game:GetService'UserInputService',game:GetService'TouchInputService',game:GetService'RunService',game:GetService'Players'local l,m=j.RenderStepped,k.LocalPlayer local n,o=m:GetMouse(),d.Parent.Parent local p=e(o.Creator)local s,t,u=p.New,o.Components,{}u.__index=u u.__type='Colorpicker'function u.New(v,w,x)local y=v.Library assert(x.Title,'Colorpicker - Missing Title')assert(x.Default,'AddColorPicker: Missing default value.')local z={Value=x.Default,Transparency=x.Transparency or 0,Type='Colorpicker',Title=type(x.Title)=='string'and x.Title or'Colorpicker',Callback=x.Callback or function(z)end}function z.SetHSVFromRGB(A,B)local C,D,E=Color3.toHSV(B)z.Hue=C z.Sat=D z.Vib=E end z:SetHSVFromRGB(z.Value)local A=e(t.Element)(x.Title,x.Description,v.Container,true)p.ApplyElementAPI(z,A,x,v.Context) local B=s('Frame',{Size=UDim2.fromScale(1,1),BackgroundColor3=z.Value,Parent=A.Frame},{s('UICorner',{CornerRadius=UDim.new(0,4)})})local aa,ab=s('ImageLabel',{Size=UDim2.fromOffset(26,26),Position=UDim2.new(1,-10,0.5,0),AnchorPoint=Vector2.new(1,0.5),Parent=A.Frame,Image='http://www.roblox.com/asset/?id=14204231522',ImageTransparency=0.45,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(40,40)},{s('UICorner',{CornerRadius=UDim.new(0,4)}),B}),function()local C=e(t.Dialog):Create()C.Title.Text=z.Title C.Root.Size=UDim2.fromOffset(430,330)local D,E,F,G,H,I=z.Hue,z.Sat,z.Vib,z.Transparency,function()local D=e(t.Textbox)()D.Frame.Parent=C.Root D.Frame.Size=UDim2.new(0,90,0,32)return D end,function(D,E)return s('TextLabel',{FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Medium,Enum.FontStyle.Normal),Text=D,TextColor3=Color3.fromRGB(240,240,240),TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,32),Position=E,BackgroundTransparency=1,Parent=C.Root,ThemeTag={TextColor3='Text'}})end local J,K=function()local J=Color3.fromHSV(D,E,F)return{R=math.floor(J.r*255),G=math.floor(J.g*255),B=math.floor(J.b*255)}end,s('ImageLabel',{Size=UDim2.new(0,18,0,18),ScaleType=Enum.ScaleType.Fit,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Image='http://www.roblox.com/asset/?id=4805639000'})local L,M=s('ImageLabel',{Size=UDim2.fromOffset(180,160),Position=UDim2.fromOffset(20,55),Image='rbxassetid://4155801252',BackgroundColor3=z.Value,BackgroundTransparency=0,Parent=C.Root},{s('UICorner',{CornerRadius=UDim.new(0,4)}),K}),s('Frame',{BackgroundColor3=z.Value,Size=UDim2.fromScale(1,1),BackgroundTransparency=z.Transparency},{s('UICorner',{CornerRadius=UDim.new(0,4)})})local N,O=s('ImageLabel',{Image='http://www.roblox.com/asset/?id=14204231522',ImageTransparency=0.45,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(40,40),BackgroundTransparency=1,Position=UDim2.fromOffset(112,220),Size=UDim2.fromOffset(88,24),Parent=C.Root},{s('UICorner',{CornerRadius=UDim.new(0,4)}),s('UIStroke',{Thickness=2,Transparency=0.75}),M}),s('Frame',{BackgroundColor3=z.Value,Size=UDim2.fromScale(1,1),BackgroundTransparency=0},{s('UICorner',{CornerRadius=UDim.new(0,4)})})local P,Q=s('ImageLabel',{Image='http://www.roblox.com/asset/?id=14204231522',ImageTransparency=0.45,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(40,40),BackgroundTransparency=1,Position=UDim2.fromOffset(20,220),Size=UDim2.fromOffset(88,24),Parent=C.Root},{s('UICorner',{CornerRadius=UDim.new(0,4)}),s('UIStroke',{Thickness=2,Transparency=0.75}),O}),{}for R=0,1,0.1 do table.insert(Q,ColorSequenceKeypoint.new(R,Color3.fromHSV(R,1,1)))end local R,S=s('UIGradient',{Color=ColorSequence.new(Q),Rotation=90}),s('Frame',{Size=UDim2.new(1,0,1,-10),Position=UDim2.fromOffset(0,5),BackgroundTransparency=1})local T,U,V=s('ImageLabel',{Size=UDim2.fromOffset(14,14),Image='http://www.roblox.com/asset/?id=12266946128',Parent=S,ThemeTag={ImageColor3='DialogInput'}}),s('Frame',{Size=UDim2.fromOffset(12,190),Position=UDim2.fromOffset(210,55),Parent=C.Root},{s('UICorner',{CornerRadius=UDim.new(1,0)}),R,S}),H()V.Frame.Position=UDim2.fromOffset(x.Transparency and 260 or 240,55)I('Hex',UDim2.fromOffset(x.Transparency and 360 or 340,55))local W=H()W.Frame.Position=UDim2.fromOffset(x.Transparency and 260 or 240,95)I('Red',UDim2.fromOffset(x.Transparency and 360 or 340,95))local X=H()X.Frame.Position=UDim2.fromOffset(x.Transparency and 260 or 240,135)I('Green',UDim2.fromOffset(x.Transparency and 360 or 340,135))local Y=H()Y.Frame.Position=UDim2.fromOffset(x.Transparency and 260 or 240,175)I('Blue',UDim2.fromOffset(x.Transparency and 360 or 340,175))local Z if x.Transparency then Z=H()Z.Frame.Position=UDim2.fromOffset(260,215)I('Alpha',UDim2.fromOffset(360,215))end local _,aa,ab if x.Transparency then local ac=s('Frame',{Size=UDim2.new(1,0,1,-10),Position=UDim2.fromOffset(0,5),BackgroundTransparency=1})aa=s('ImageLabel',{Size=UDim2.fromOffset(14,14),Image='http://www.roblox.com/asset/?id=12266946128',Parent=ac,ThemeTag={ImageColor3='DialogInput'}})ab=s('Frame',{Size=UDim2.fromScale(1,1)},{s('UIGradient',{Transparency=NumberSequence.new{NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)},Rotation=270}),s('UICorner',{CornerRadius=UDim.new(1,0)})})_=s('Frame',{Size=UDim2.fromOffset(12,190),Position=UDim2.fromOffset(230,55),Parent=C.Root,BackgroundTransparency=1},{s('UICorner',{CornerRadius=UDim.new(1,0)}),s('ImageLabel',{Image='http://www.roblox.com/asset/?id=14204231522',ImageTransparency=0.45,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(40,40),BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Parent=C.Root},{s('UICorner',{CornerRadius=UDim.new(1,0)})}),ab,ac})end local ac=function()L.BackgroundColor3=Color3.fromHSV(D,1,1)T.Position=UDim2.new(0,-1,D,-6)K.Position=UDim2.new(E,0,1-F,0)O.BackgroundColor3=Color3.fromHSV(D,E,F)V.Input.Text='#'..Color3.fromHSV(D,E,F):ToHex()W.Input.Text=J().R X.Input.Text=J().G Y.Input.Text=J().B if x.Transparency then ab.BackgroundColor3=Color3.fromHSV(D,E,F)O.BackgroundTransparency=G aa.Position=UDim2.new(0,-1,1-G,-6)Z.Input.Text=e(o):Round((1-G)*100,0)..'%'end end p.AddSignal(V.Input.FocusLost,function(ad)if ad then local ae,af=pcall(Color3.fromHex,V.Input.Text)if ae and typeof(af)=='Color3'then D,E,F=Color3.toHSV(af)end end ac()end)p.AddSignal(W.Input.FocusLost,function(ad)if ad then local ae=J()local af,ag=pcall(Color3.fromRGB,W.Input.Text,ae.G,ae.B)if af and typeof(ag)=='Color3'then if tonumber(W.Input.Text)<=255 then D,E,F=Color3.toHSV(ag)end end end ac()end)p.AddSignal(X.Input.FocusLost,function(ad)if ad then local ae=J()local af,ag=pcall(Color3.fromRGB,ae.R,X.Input.Text,ae.B)if af and typeof(ag)=='Color3'then if tonumber(X.Input.Text)<=255 then D,E,F=Color3.toHSV(ag)end end end ac()end)p.AddSignal(Y.Input.FocusLost,function(ad)if ad then local ae=J()local af,ag=pcall(Color3.fromRGB,ae.R,ae.G,Y.Input.Text)if af and typeof(ag)=='Color3'then if tonumber(Y.Input.Text)<=255 then D,E,F=Color3.toHSV(ag)end end end ac()end)if x.Transparency then p.AddSignal(Z.Input.FocusLost,function(ad)if ad then pcall(function()local ae=tonumber(Z.Input.Text)if ae>=0 and ae<=100 then G=1-ae*0.01 end end)end ac()end)end p.AddSignal(L.InputBegan,function(ad)if ad.UserInputType==Enum.UserInputType.MouseButton1 or ad.UserInputType==Enum.UserInputType.Touch then while h:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)do local ae=L.AbsolutePosition.X local af=ae+L.AbsoluteSize.X local ag,ah=math.clamp(n.X,ae,af),L.AbsolutePosition.Y local ai=ah+L.AbsoluteSize.Y local aj=math.clamp(n.Y,ah,ai)E=(ag-ae)/(af-ae)F=1-((aj-ah)/(ai-ah))ac()l:Wait()end end end)p.AddSignal(U.InputBegan,function(ad)if ad.UserInputType==Enum.UserInputType.MouseButton1 or ad.UserInputType==Enum.UserInputType.Touch then while h:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)do local ae=U.AbsolutePosition.Y local af=ae+U.AbsoluteSize.Y local ag=math.clamp(n.Y,ae,af)D=((ag-ae)/(af-ae))ac()l:Wait()end end end)if x.Transparency then p.AddSignal(_.InputBegan,function(ad)if ad.UserInputType==Enum.UserInputType.MouseButton1 then while h:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)do local ae=_.AbsolutePosition.Y local af=ae+_.AbsoluteSize.Y local ag=math.clamp(n.Y,ae,af)G=1-((ag-ae)/(af-ae))ac()l:Wait()end end end)end ac()C:Button('Done',function()z:SetValue({D,E,F},G)end)C:Button'Cancel'C:Open()end function z.Display(ac)z.Value=Color3.fromHSV(z.Hue,z.Sat,z.Vib)B.BackgroundColor3=z.Value B.BackgroundTransparency=z.Transparency u.Library:SafeCallback(z.Callback,z.Value)u.Library:SafeCallback(z.Changed,z.Value)end function z.SetValue(ac,ad,ae)local af=Color3.fromHSV(ad[1],ad[2],ad[3])z.Transparency=ae or 0 z:SetHSVFromRGB(af)z:Display()end function z.SetValueRGB(ac,ad,ae)z.Transparency=ae or 0 z:SetHSVFromRGB(ad)z:Display()end function z.OnChanged(ac,ad)z.Changed=ad ad(z.Value)end function z.Destroy(ac)A:Destroy()y.Options[w]=nil end p.AddSignal(A.Frame.MouseButton1Click,function()if A.Locked then return end ab()end)z:Display()y.Options[w]=z return z end return u end,
[22]=function()
local aa,ab,ac,ad,ae=b(22)
local TweenService=game:GetService'TweenService'
local UserInputService=game:GetService'UserInputService'
local Mouse=game:GetService'Players'.LocalPlayer:GetMouse()
local Camera=game:GetService'Workspace'.CurrentCamera
local Root=ab.Parent.Parent
local Creator=ac(Root.Creator)
local Flipper=ac(Root.Packages.Flipper)
local New=Creator.New
local Components=Root.Components

local Dropdown={}
Dropdown.__index=Dropdown
Dropdown.__type='Dropdown'

function Dropdown.New(self,idx,config)
    local Library=self.Library
    config=config or{}
    config.Values=config.Values or{}

    local isMulti=(config.Multi==true)
    local isOrdered=isMulti and(config.Ordered==true or config.Priority==true)
    local isSearchable=(config.Searchable~=false)
    local hasSelectAll=isMulti and(config.AllowSelectAll~=false)

    local DropObj={
        Values=config.Values,
        Value=isMulti and{}or nil,
        Order={},
        Multi=isMulti,
        Ordered=isOrdered,
        Searchable=isSearchable,
        Buttons={},
        OptionItems={},
        OptionByKey={},
        Opened=false,
        Type='Dropdown',
        SearchQuery='',
        Callback=config.Callback or function()end
    }

    local Elem=ac(Components.Element)(config.Title,config.Description,self.Container,false)
    Elem.DescLabel.Size=UDim2.new(1,-170,0,14)
    Creator.ApplyElementAPI(DropObj,Elem,config,self.Context)

    local ValueLabel=New('TextLabel',{
        FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Regular,Enum.FontStyle.Normal),
        Text='--',
        RichText=true,
        TextColor3=Color3.fromRGB(240,240,240),
        TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.new(1,-30,0,14),
        Position=UDim2.new(0,8,0.5,0),
        AnchorPoint=Vector2.new(0,0.5),
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BackgroundTransparency=1,
        TextTruncate=Enum.TextTruncate.AtEnd,
        ThemeTag={TextColor3='Text'}
    })

    local ChevronIcon=New('ImageLabel',{
        Image='rbxassetid://10709790948',
        Size=UDim2.fromOffset(16,16),
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-8,0.5,0),
        BackgroundTransparency=1,
        ThemeTag={ImageColor3='SubText'}
    })

    local DropButton=New('TextButton',{
        Size=UDim2.fromOffset(160,30),
        Position=UDim2.new(1,-10,0.5,0),
        AnchorPoint=Vector2.new(1,0.5),
        BackgroundTransparency=0.9,
        Parent=Elem.Frame,
        ThemeTag={BackgroundColor3='DropdownFrame'}
    },{
        New('UICorner',{CornerRadius=UDim.new(0,5)}),
        New('UIStroke',{
            Transparency=0.5,
            ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
            ThemeTag={Color='InElementBorder'}
        }),
        ChevronIcon,
        ValueLabel
    })

    local topPad=6+(isSearchable and 32 or 0)+(hasSelectAll and 26 or 0)
    local ListLayout=New('UIListLayout',{
        Padding=UDim.new(0,3),
        SortOrder=Enum.SortOrder.LayoutOrder
    })

    local OptionsScroll=New('ScrollingFrame',{
        Size=UDim2.new(1,-5,1,-(topPad+5)),
        Position=UDim2.fromOffset(5,topPad),
        BackgroundTransparency=1,
        BottomImage='rbxassetid://6889812791',
        MidImage='rbxassetid://6889812721',
        TopImage='rbxassetid://6276641225',
        ScrollBarImageColor3=Color3.fromRGB(255,255,255),
        ScrollBarImageTransparency=0.95,
        ScrollBarThickness=4,
        BorderSizePixel=0,
        CanvasSize=UDim2.fromScale(0,0)
    },{ListLayout})

    local SearchBox,ClearSearchBtn,SearchFrame
    if isSearchable then
        SearchBox=New('TextBox',{
            FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Regular,Enum.FontStyle.Normal),
            Text='',
            PlaceholderText=config.SearchPlaceholder or'Search...',
            TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left,
            Size=UDim2.new(1,-44,1,0),
            Position=UDim2.fromOffset(24,0),
            BackgroundTransparency=1,
            ClearTextOnFocus=false,
            ZIndex=24,
            ThemeTag={TextColor3='Text',PlaceholderColor3='SubText'}
        })
        ClearSearchBtn=New('TextButton',{
            Size=UDim2.fromOffset(16,16),
            Position=UDim2.new(1,-5,0.5,0),
            AnchorPoint=Vector2.new(1,0.5),
            BackgroundTransparency=1,
            Text='',
            Visible=false,
            ZIndex=25
        },{
            New('ImageLabel',{
                Image='rbxassetid://10747384394',
                Size=UDim2.fromOffset(11,11),
                Position=UDim2.fromScale(0.5,0.5),
                AnchorPoint=Vector2.new(0.5,0.5),
                BackgroundTransparency=1,
                ZIndex=25,
                ThemeTag={ImageColor3='SubText'}
            })
        })
        SearchFrame=New('Frame',{
            Size=UDim2.new(1,-12,0,26),
            Position=UDim2.fromOffset(6,6),
            BackgroundTransparency=0.86,
            ZIndex=23,
            ThemeTag={BackgroundColor3='Input'}
        },{
            New('UICorner',{CornerRadius=UDim.new(0,5)}),
            New('UIStroke',{
                ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
                Thickness=1,
                Transparency=0.5,
                ThemeTag={Color='InElementBorder'}
            }),
            New('ImageLabel',{
                Image='rbxassetid://10734943674',
                Size=UDim2.fromOffset(12,12),
                Position=UDim2.new(0,7,0.5,0),
                AnchorPoint=Vector2.new(0,0.5),
                BackgroundTransparency=1,
                ZIndex=24,
                ThemeTag={ImageColor3='SubText'}
            }),
            SearchBox,
            ClearSearchBtn
        })
    end

    local ActionRow,SelectAllBtn,DeselectAllBtn
    if hasSelectAll then
        local function makeMiniBtn(label,pos,size)
            local txt=New('TextLabel',{
                FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Medium,Enum.FontStyle.Normal),
                Text=label,
                TextSize=11,
                Size=UDim2.fromScale(1,1),
                BackgroundTransparency=1,
                ZIndex=25,
                ThemeTag={TextColor3='Text'}
            })
            local btn=New('TextButton',{
                Size=size,
                Position=pos,
                BackgroundTransparency=0.88,
                Text='',
                ZIndex=24,
                ThemeTag={BackgroundColor3='DropdownOption'}
            },{
                New('UICorner',{CornerRadius=UDim.new(0,4)}),
                New('UIStroke',{
                    ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
                    Thickness=1,
                    Transparency=0.55,
                    ThemeTag={Color='InElementBorder'}
                }),
                txt
            })
            return btn
        end
        SelectAllBtn=makeMiniBtn('Select All',UDim2.fromScale(0,0),UDim2.new(0.5,-3,1,0))
        DeselectAllBtn=makeMiniBtn('Deselect All',UDim2.new(0.5,3,0,0),UDim2.new(0.5,-3,1,0))
        ActionRow=New('Frame',{
            Size=UDim2.new(1,-12,0,22),
            Position=UDim2.fromOffset(6,isSearchable and 36 or 6),
            BackgroundTransparency=1,
            ZIndex=23
        },{SelectAllBtn,DeselectAllBtn})
    end

    local holderChildren={
        OptionsScroll,
        New('UICorner',{CornerRadius=UDim.new(0,7)}),
        New('UIStroke',{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,ThemeTag={Color='DropdownBorder'}}),
        New('ImageLabel',{
            BackgroundTransparency=1,
            Image='http://www.roblox.com/asset/?id=5554236805',
            ScaleType=Enum.ScaleType.Slice,
            SliceCenter=Rect.new(23,23,277,277),
            Size=UDim2.fromScale(1,1)+UDim2.fromOffset(30,30),
            Position=UDim2.fromOffset(-15,-15),
            ImageColor3=Color3.fromRGB(0,0,0),
            ImageTransparency=0.1
        })
    }
    if SearchFrame then table.insert(holderChildren,SearchFrame)end
    if ActionRow then table.insert(holderChildren,ActionRow)end

    local MenuHolder=New('Frame',{
        Size=UDim2.fromScale(1,0.6),
        ThemeTag={BackgroundColor3='DropdownHolder'}
    },holderChildren)

    local PopupRoot=New('Frame',{
        BackgroundTransparency=1,
        Size=UDim2.fromOffset(180,300),
        Parent=self.Library.GUI,
        Visible=false
    },{
        MenuHolder,
        New('UISizeConstraint',{MinSize=Vector2.new(175,0)})
    })
    table.insert(Library.OpenFrames,PopupRoot)
    table.insert(Library.OpenDropdowns,DropObj)

    Elem.OnLockChanged=function(locked)
        if locked and DropObj.Opened then
            DropObj:Close()
        end
    end

    local maxWidth=180
    local function UpdatePopupPosition()
        local extraOffset=0
        if Camera.ViewportSize.Y-DropButton.AbsolutePosition.Y<PopupRoot.AbsoluteSize.Y-5 then
            extraOffset=PopupRoot.AbsoluteSize.Y-5-(Camera.ViewportSize.Y-DropButton.AbsolutePosition.Y)+40
        end
        local posX=DropButton.AbsolutePosition.X-1
        if posX+PopupRoot.AbsoluteSize.X>Camera.ViewportSize.X-8 then
            posX=math.max(8,Camera.ViewportSize.X-PopupRoot.AbsoluteSize.X-8)
        end
        PopupRoot.Position=UDim2.fromOffset(posX,DropButton.AbsolutePosition.Y-5-extraOffset)
    end

    local function GetComputedListHeight()
        local visibleCount=0
        for _,item in ipairs(DropObj.OptionItems)do
            if item.Button.Visible then visibleCount=visibleCount+1 end
        end
        local layoutY=ListLayout.AbsoluteContentSize.Y
        local mathY=(visibleCount>0)and(visibleCount*32+(visibleCount-1)*3)or 0
        return math.max(layoutY,mathY),visibleCount
    end

    local function UpdatePopupSize()
        local listH,visibleCount=GetComputedListHeight()
        local contentH=listH+topPad+8
        if visibleCount>10 or contentH>392 then
            PopupRoot.Size=UDim2.fromOffset(maxWidth,392)
        else
            PopupRoot.Size=UDim2.fromOffset(maxWidth,math.max(contentH,topPad+38))
        end
    end

    local function UpdateCanvas()
        local listH=GetComputedListHeight()
        OptionsScroll.CanvasSize=UDim2.fromOffset(0,listH)
    end

    local function ExtractOptionMeta(rawEntry,index)
        local key,title,icon,tag,tagColor
        if type(rawEntry)=='table'then
            key=rawEntry.Value or rawEntry.Id or rawEntry.Name or rawEntry.Title or tostring(index)
            title=rawEntry.Title or rawEntry.Text or rawEntry.Label or tostring(key)
            icon=rawEntry.Icon
            tag=rawEntry.Tag or rawEntry.Badge
            tagColor=rawEntry.TagColor or rawEntry.BadgeColor or rawEntry.Color
        else
            key=rawEntry
            title=tostring(rawEntry)
        end
        if not icon then
            local iconMap=config.Icons or config.OptionIcons
            if iconMap then icon=iconMap[key]end
        end
        if not tag then
            local tagMap=config.Tags or config.OptionTags
            if tagMap then tag=tagMap[key]end
        end
        if type(tag)=='table'then
            tagColor=tag.Color or tag[2]or tagColor
            tag=tag.Text or tag.Title or tag[1]
        end
        local resolvedIcon=Library:GetIcon(icon)
        local cleanTitle=tostring(title):gsub('<[^>]+>','')
        local cleanTag=tag and tostring(tag):gsub('<[^>]+>','')or''
        return{
            Key=key,
            Title=tostring(title),
            CleanTitle=cleanTitle,
            Icon=resolvedIcon,
            Tag=tag and tostring(tag)or nil,
            TagColor=tagColor,
            SearchText=(cleanTitle..' '..tostring(key)..' '..cleanTag):lower()
        }
    end

    function DropObj.SyncOrder(self)
        if not isMulti then return end
        local validOrder={}
        local seen={}
        for _,k in ipairs(DropObj.Order)do
            if DropObj.Value[k]and DropObj.OptionByKey[k]and not seen[k]then
                seen[k]=true
                table.insert(validOrder,k)
            end
        end
        for _,item in ipairs(DropObj.OptionItems)do
            local k=item.Key
            if DropObj.Value[k]and not seen[k]then
                seen[k]=true
                table.insert(validOrder,k)
            end
        end
        DropObj.Order=validOrder
        for k in next,DropObj.Value do
            if not seen[k]then
                DropObj.Value[k]=nil
            end
        end
        if isOrdered then
            for rank,k in ipairs(DropObj.Order)do
                DropObj.Value[k]=rank
            end
        else
            for _,k in ipairs(DropObj.Order)do
                DropObj.Value[k]=true
            end
        end
    end

    function DropObj.GetOrderedValues(self)
        if isMulti then
            DropObj:SyncOrder()
            local copy={}
            for i,k in ipairs(DropObj.Order)do copy[i]=k end
            return copy
        end
        return DropObj.Value and{DropObj.Value}or{}
    end

    function DropObj.Display(self)
        local str=''
        if isMulti then
            DropObj:SyncOrder()
            if isOrdered then
                local parts={}
                for rank,k in ipairs(DropObj.Order)do
                    local item=DropObj.OptionByKey[k]
                    local lbl=item and item.Meta.Title or tostring(k)
                    table.insert(parts,rank..'. '..lbl)
                end
                str=table.concat(parts,', ')
            else
                local parts={}
                for _,item in ipairs(DropObj.OptionItems)do
                    if DropObj.Value[item.Key]then
                        table.insert(parts,item.Meta.Title)
                    end
                end
                str=table.concat(parts,', ')
            end
        else
            if DropObj.Value~=nil then
                local item=DropObj.OptionByKey[DropObj.Value]
                str=item and item.Meta.Title or tostring(DropObj.Value)
            end
        end
        ValueLabel.Text=(str==''and'--'or str)
    end

    function DropObj.GetActiveValues(self)
        if isMulti then
            local arr={}
            for k,v in next,DropObj.Value do
                if v then table.insert(arr,k)end
            end
            return arr
        else
            return DropObj.Value and 1 or 0
        end
    end

    function DropObj.UpdateAllButtons(self)
        DropObj:SyncOrder()
        for _,item in ipairs(DropObj.OptionItems)do
            item:UpdateButton()
        end
        DropObj:Display()
    end

    function DropObj.ApplyFilter(self,rawQuery)
        local q=(rawQuery or''):lower():gsub('^%s+',''):gsub('%s+$','')
        DropObj.SearchQuery=q
        if ClearSearchBtn then
            ClearSearchBtn.Visible=(q~='')
        end
        for _,item in ipairs(DropObj.OptionItems)do
            if q==''then
                item.Button.Visible=true
            else
                item.Button.Visible=(item.Meta.SearchText:find(q,1,true)~=nil)
            end
        end
        UpdateCanvas()
        UpdatePopupSize()
        UpdatePopupPosition()
    end

    if SearchBox then
        Creator.AddSignal(SearchBox:GetPropertyChangedSignal'Text',function()
            DropObj:ApplyFilter(SearchBox.Text)
        end)
        Creator.AddSignal(ClearSearchBtn.MouseButton1Click,function()
            SearchBox.Text=''
        end)
    end

    if hasSelectAll then
        Creator.AddSignal(SelectAllBtn.MouseButton1Click,function()
            for _,item in ipairs(DropObj.OptionItems)do
                if item.Button.Visible then
                    if not DropObj.Value[item.Key]then
                        DropObj.Value[item.Key]=true
                        table.insert(DropObj.Order,item.Key)
                    end
                end
            end
            DropObj:UpdateAllButtons()
            Library:SafeCallback(DropObj.Callback,DropObj.Value)
            Library:SafeCallback(DropObj.Changed,DropObj.Value)
        end)
        Creator.AddSignal(DeselectAllBtn.MouseButton1Click,function()
            if DropObj.SearchQuery~=''then
                for _,item in ipairs(DropObj.OptionItems)do
                    if item.Button.Visible then
                        DropObj.Value[item.Key]=nil
                    end
                end
            else
                table.clear(DropObj.Value)
                table.clear(DropObj.Order)
            end
            DropObj:UpdateAllButtons()
            Library:SafeCallback(DropObj.Callback,DropObj.Value)
            Library:SafeCallback(DropObj.Changed,DropObj.Value)
        end)
    end

    local ParentScroll=self.ScrollFrame
    function DropObj.Open(self)
        if Elem.Locked then return end
        Library:CloseAllDropdowns(DropObj)
        DropObj.Opened=true
        if ParentScroll then ParentScroll.ScrollingEnabled=false end
        PopupRoot.Visible=true
        UpdateCanvas()
        UpdatePopupSize()
        UpdatePopupPosition()
        TweenService:Create(
            MenuHolder,
            TweenInfo.new(0.2,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
            {Size=UDim2.fromScale(1,1)}
        ):Play()
    end

    function DropObj.Close(self)
        if not DropObj.Opened then return end
        DropObj.Opened=false
        if ParentScroll then ParentScroll.ScrollingEnabled=true end
        MenuHolder.Size=UDim2.fromScale(1,0.6)
        PopupRoot.Visible=false
        if SearchBox and SearchBox.Text~=''then
            SearchBox.Text=''
        end
    end

    Creator.AddSignal(DropButton:GetPropertyChangedSignal'AbsolutePosition',function()
        if DropObj.Opened then UpdatePopupPosition()end
    end)
    Creator.AddSignal(DropButton.MouseButton1Click,function()
        if Elem.Locked then return end
        if DropObj.Opened then
            DropObj:Close()
        else
            DropObj:Open()
        end
    end)
    Creator.AddSignal(UserInputService.InputBegan,function(input)
        if not DropObj.Opened then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            local absPos,absSize=MenuHolder.AbsolutePosition,MenuHolder.AbsoluteSize
            local btnPos,btnSize=DropButton.AbsolutePosition,DropButton.AbsoluteSize
            local inButton=(Mouse.X>=btnPos.X and Mouse.X<=btnPos.X+btnSize.X and Mouse.Y>=btnPos.Y and Mouse.Y<=btnPos.Y+btnSize.Y)
            if not inButton and(Mouse.X<absPos.X or Mouse.X>absPos.X+absSize.X or Mouse.Y<(absPos.Y-20-1)or Mouse.Y>absPos.Y+absSize.Y)then
                DropObj:Close()
            end
        end
    end)

    function DropObj.BuildDropdownList(self)
        for _,oldItem in ipairs(DropObj.OptionItems)do
            if oldItem.StopMotors then pcall(oldItem.StopMotors)end
        end
        for _,child in next,OptionsScroll:GetChildren()do
            if not child:IsA'UIListLayout'then
                child:Destroy()
            end
        end
        table.clear(DropObj.OptionItems)
        table.clear(DropObj.OptionByKey)
        table.clear(DropObj.Buttons)

        for index,rawEntry in ipairs(DropObj.Values)do
            local meta=ExtractOptionMeta(rawEntry,index)
            local key=meta.Key
            local ItemController={
                Key=key,
                Meta=meta
            }

            local SelectorBar=New('Frame',{
                Size=UDim2.fromOffset(4,14),
                BackgroundColor3=Color3.fromRGB(76,194,255),
                Position=UDim2.fromOffset(-1,16),
                AnchorPoint=Vector2.new(0,0.5),
                ZIndex=24,
                ThemeTag={BackgroundColor3='Accent'}
            },{New('UICorner',{CornerRadius=UDim.new(0,2)})})

            local leftOffset=meta.Icon and 32 or 10
            local rightReserve=10+(meta.Tag and 56 or 0)+(isOrdered and 28 or 0)

            local OptionChildren={
                SelectorBar,
                New('UICorner',{CornerRadius=UDim.new(0,6)})
            }

            if meta.Icon then
                table.insert(OptionChildren,New('ImageLabel',{
                    Image=meta.Icon,
                    Size=UDim2.fromOffset(16,16),
                    Position=UDim2.new(0,10,0.5,0),
                    AnchorPoint=Vector2.new(0,0.5),
                    BackgroundTransparency=1,
                    ZIndex=24
                }))
            end

            local ButtonLabel=New('TextLabel',{
                FontFace=Font.new'rbxasset://fonts/families/GothamSSm.json',
                Text=meta.Title,
                RichText=true,
                TextColor3=Color3.fromRGB(200,200,200),
                TextSize=13,
                TextXAlignment=Enum.TextXAlignment.Left,
                BackgroundColor3=Color3.fromRGB(255,255,255),
                BackgroundTransparency=1,
                Size=UDim2.new(1,-(leftOffset+rightReserve),1,0),
                Position=UDim2.fromOffset(leftOffset,0),
                TextTruncate=Enum.TextTruncate.AtEnd,
                Name='ButtonLabel',
                ZIndex=24,
                ThemeTag={TextColor3='Text'}
            })
            table.insert(OptionChildren,ButtonLabel)

            local PriorityBadge,PriorityText
            if isOrdered then
                PriorityText=New('TextLabel',{
                    FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Bold,Enum.FontStyle.Normal),
                    Text='#1',
                    TextSize=10,
                    Size=UDim2.fromScale(1,1),
                    BackgroundTransparency=1,
                    ZIndex=25,
                    ThemeTag={TextColor3='ToggleToggled'}
                })
                PriorityBadge=New('Frame',{
                    Size=UDim2.fromOffset(22,17),
                    Position=UDim2.new(1,-6,0.5,0),
                    AnchorPoint=Vector2.new(1,0.5),
                    Visible=false,
                    ZIndex=24,
                    ThemeTag={BackgroundColor3='Accent'}
                },{
                    New('UICorner',{CornerRadius=UDim.new(0,4)}),
                    PriorityText
                })
                table.insert(OptionChildren,PriorityBadge)
            end

            if meta.Tag then
                local tagRightOffset=isOrdered and-32 or-6
                local tagBgProps={
                    AutomaticSize=Enum.AutomaticSize.X,
                    Size=UDim2.fromOffset(0,16),
                    Position=UDim2.new(1,tagRightOffset,0.5,0),
                    AnchorPoint=Vector2.new(1,0.5),
                    BackgroundTransparency=meta.TagColor and 0.8 or 0.85,
                    BackgroundColor3=meta.TagColor or Color3.fromRGB(96,205,255),
                    ZIndex=24
                }
                if not meta.TagColor then
                    tagBgProps.ThemeTag={BackgroundColor3='Accent'}
                end
                local tagTxtProps={
                    FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal),
                    Text=meta.Tag,
                    TextSize=10,
                    AutomaticSize=Enum.AutomaticSize.X,
                    Size=UDim2.fromOffset(0,14),
                    BackgroundTransparency=1,
                    TextColor3=meta.TagColor or Color3.fromRGB(240,240,240),
                    ZIndex=25
                }
                if not meta.TagColor then
                    tagTxtProps.ThemeTag={TextColor3='Text'}
                end
                table.insert(OptionChildren,New('Frame',tagBgProps,{
                    New('UICorner',{CornerRadius=UDim.new(0,4)}),
                    New('UIPadding',{PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,5)}),
                    New('TextLabel',tagTxtProps)
                }))
            end

            local OptionBtn=New('TextButton',{
                Size=UDim2.new(1,-5,0,32),
                BackgroundTransparency=1,
                ZIndex=23,
                Text='',
                LayoutOrder=index,
                Parent=OptionsScroll,
                ThemeTag={BackgroundColor3='DropdownOption'}
            },OptionChildren)

            local bgMotor,setBgGoal=Creator.SpringMotor(1,OptionBtn,'BackgroundTransparency')
            local barMotor,setBarGoal=Creator.SpringMotor(1,SelectorBar,'BackgroundTransparency')
            local sizeMotor=Flipper.SingleMotor.new(6)
            sizeMotor:onStep(function(sz)
                SelectorBar.Size=UDim2.new(0,4,0,sz)
            end)

            ItemController.StopMotors=function()
                bgMotor:stop()
                barMotor:stop()
                sizeMotor:stop()
            end

            local isSelected=false
            Creator.AddSignal(OptionBtn.MouseEnter,function()
                setBgGoal(isSelected and 0.85 or 0.89)
            end)
            Creator.AddSignal(OptionBtn.MouseLeave,function()
                setBgGoal(isSelected and 0.89 or 1)
            end)
            Creator.AddSignal(OptionBtn.MouseButton1Down,function()
                setBgGoal(0.92)
            end)
            Creator.AddSignal(OptionBtn.MouseButton1Up,function()
                setBgGoal(isSelected and 0.85 or 0.89)
            end)

            function ItemController.UpdateButton(self)
                if isMulti then
                    local v=DropObj.Value[key]
                    isSelected=(v~=nil and v~=false)
                    setBgGoal(isSelected and 0.89 or 1)
                    if isOrdered and PriorityBadge then
                        PriorityBadge.Visible=isSelected
                        if isSelected and type(v)=='number'then
                            PriorityText.Text='#'..tostring(v)
                        end
                    end
                else
                    isSelected=(DropObj.Value==key)
                    setBgGoal(isSelected and 0.89 or 1)
                end
                sizeMotor:setGoal(Flipper.Spring.new(isSelected and 14 or 6,{frequency=6}))
                setBarGoal(isSelected and 0 or 1)
            end

            Creator.AddSignal(OptionBtn.MouseButton1Click,function()
                if Elem.Locked then return end
                local targetState=not isSelected
                if DropObj:GetActiveValues()==1 and not targetState and not config.AllowNull and not isMulti then
                    return
                end
                if isMulti then
                    isSelected=targetState
                    if isSelected then
                        table.insert(DropObj.Order,key)
                        DropObj.Value[key]=isOrdered and #DropObj.Order or true
                    else
                        DropObj.Value[key]=nil
                    end
                    DropObj:UpdateAllButtons()
                else
                    isSelected=targetState
                    DropObj.Value=isSelected and key or nil
                    for _,it in ipairs(DropObj.OptionItems)do
                        it:UpdateButton()
                    end
                    DropObj:Display()
                end
                Library:SafeCallback(DropObj.Callback,DropObj.Value)
                Library:SafeCallback(DropObj.Changed,DropObj.Value)
            end)

            ItemController.Button=OptionBtn
            ItemController.ButtonLabel=ButtonLabel
            table.insert(DropObj.OptionItems,ItemController)
            DropObj.OptionByKey[key]=ItemController
            DropObj.Buttons[OptionBtn]=ItemController
        end

        DropObj:UpdateAllButtons()

        maxWidth=180
        local extraSearchParts={}
        for _,item in ipairs(DropObj.OptionItems)do
            local textW=math.max(item.ButtonLabel.TextBounds.X,#item.Meta.CleanTitle*7)
            local w=textW+40+(item.Meta.Icon and 24 or 0)+(item.Meta.Tag and 60 or 0)+(isOrdered and 30 or 0)
            if w>maxWidth then maxWidth=w end
            table.insert(extraSearchParts,item.Meta.SearchText)
        end
        Elem.ExtraSearchText=table.concat(extraSearchParts,' ')
        if SearchBox and DropObj.SearchQuery~=''then
            DropObj:ApplyFilter(DropObj.SearchQuery)
        else
            UpdateCanvas()
            UpdatePopupSize()
            UpdatePopupPosition()
        end
    end

    local function ApplyMultiTable(inputTbl)
        table.clear(DropObj.Value)
        table.clear(DropObj.Order)
        if type(inputTbl)~='table'then return end

        local rankedEntries={}
        local isArray=false
        for k,v in next,inputTbl do
            if type(k)=='number'and DropObj.OptionByKey[v]~=nil and DropObj.OptionByKey[k]==nil then
                isArray=true
                break
            end
        end

        if isArray then
            for _,valKey in ipairs(inputTbl)do
                if DropObj.OptionByKey[valKey]and not DropObj.Value[valKey]then
                    table.insert(DropObj.Order,valKey)
                    DropObj.Value[valKey]=true
                end
            end
        else
            for k,v in next,inputTbl do
                if v and DropObj.OptionByKey[k]then
                    local rank=(type(v)=='number')and v or 999999
                    table.insert(rankedEntries,{Key=k,Rank=rank})
                end
            end
            table.sort(rankedEntries,function(a,b)
                if a.Rank~=b.Rank then return a.Rank<b.Rank end
                return tostring(a.Key)<tostring(b.Key)
            end)
            for _,entry in ipairs(rankedEntries)do
                table.insert(DropObj.Order,entry.Key)
                DropObj.Value[entry.Key]=true
            end
        end
        DropObj:SyncOrder()
    end

    function DropObj.SetValues(self,newValues)
        if newValues then DropObj.Values=newValues end
        DropObj:BuildDropdownList()
    end

    function DropObj.OnChanged(self,cb)
        DropObj.Changed=cb
        cb(DropObj.Value)
    end

    function DropObj.SetValue(self,val)
        if DropObj.Multi then
            ApplyMultiTable(val)
        else
            if not val then
                DropObj.Value=nil
            elseif DropObj.OptionByKey[val]then
                DropObj.Value=val
            end
        end
        DropObj:UpdateAllButtons()
        Library:SafeCallback(DropObj.Callback,DropObj.Value)
        Library:SafeCallback(DropObj.Changed,DropObj.Value)
    end

    function DropObj.Destroy(self)
        for _,oldItem in ipairs(DropObj.OptionItems)do
            if oldItem.StopMotors then pcall(oldItem.StopMotors)end
        end
        pcall(function()PopupRoot:Destroy()end)
        Elem:Destroy()
        Library.Options[idx]=nil
    end

    DropObj:BuildDropdownList()

    if config.Default~=nil then
        if isMulti then
            if type(config.Default)=='table'then
                ApplyMultiTable(config.Default)
            elseif type(config.Default)=='string'and DropObj.OptionByKey[config.Default]then
                ApplyMultiTable({config.Default})
            elseif type(config.Default)=='number'and DropObj.OptionItems[config.Default]then
                ApplyMultiTable({DropObj.OptionItems[config.Default].Key})
            end
        else
            if type(config.Default)=='number'and DropObj.OptionItems[config.Default]and not DropObj.OptionByKey[config.Default]then
                DropObj.Value=DropObj.OptionItems[config.Default].Key
            elseif DropObj.OptionByKey[config.Default]then
                DropObj.Value=config.Default
            end
        end
        DropObj:UpdateAllButtons()
    end

    Library.Options[idx]=DropObj
    return DropObj
end

return Dropdown
end,
[23]=function()
local aa,ab,ac,ad,ae=b(23)
local Root=ab.Parent.Parent
local Creator=ac(Root.Creator)
local New=Creator.New
local AddSignal=Creator.AddSignal
local Components=Root.Components

local InputElem={}
InputElem.__index=InputElem
InputElem.__type='Input'

function InputElem.New(self,idx,config)
    local Library=self.Library
    assert(config.Title,'Input - Missing Title')
    config.Callback=config.Callback or function()end

    local InputObj={
        Value=config.Default or'',
        Numeric=config.Numeric or false,
        Finished=config.Finished or false,
        Callback=config.Callback or function()end,
        Type='Input'
    }

    local Elem=ac(Components.Element)(config.Title,config.Description,self.Container,false)
    local TextboxComp=ac(Components.Textbox)(Elem.Frame,true)
    TextboxComp.Frame.Position=UDim2.new(1,-10,0.5,0)
    TextboxComp.Frame.AnchorPoint=Vector2.new(1,0.5)
    TextboxComp.Frame.Size=UDim2.fromOffset(160,30)
    TextboxComp.Input.Text=config.Default or''
    TextboxComp.Input.PlaceholderText=config.Placeholder or''

    local Box=TextboxComp.Input
    Elem.OnLockChanged=function(locked)
        Box.TextEditable=not locked
        if locked and Box:IsFocused()then
            Box:ReleaseFocus()
        end
    end

    Creator.ApplyElementAPI(InputObj,Elem,config,self.Context)

    function InputObj.SetValue(self,text)
        text=tostring(text or'')
        if config.MaxLength and #text>config.MaxLength then
            text=text:sub(1,config.MaxLength)
        end
        if InputObj.Numeric then
            if(not tonumber(text))and text:len()>0 then
                text=InputObj.Value
            end
        end
        InputObj.Value=text
        if Box.Text~=text then Box.Text=text end
        Library:SafeCallback(InputObj.Callback,InputObj.Value)
        Library:SafeCallback(InputObj.Changed,InputObj.Value)
    end

    if InputObj.Finished then
        AddSignal(Box.FocusLost,function(enterPressed)
            if Elem.Locked then return end
            if not enterPressed then return end
            InputObj:SetValue(Box.Text)
        end)
    else
        AddSignal(Box:GetPropertyChangedSignal'Text',function()
            if Elem.Locked then return end
            InputObj:SetValue(Box.Text)
        end)
    end

    function InputObj.OnChanged(self,cb)
        InputObj.Changed=cb
        cb(InputObj.Value)
    end

    function InputObj.Destroy(self)
        Elem:Destroy()
        Library.Options[idx]=nil
    end

    Library.Options[idx]=InputObj
    return InputObj
end

return InputElem
end,
[24]=function()local aa,ab,ac,ad,ae=b(24)local af,ag=game:GetService'UserInputService',ab.Parent.Parent local ah=ac(ag.Creator)local ai,aj,c=ah.New,ag.Components,{}c.__index=c c.__type='Keybind'function c.New(d,e,f)local g=d.Library assert(f.Title,'KeyBind - Missing Title')assert(f.Default,'KeyBind - Missing default value.')local h,i,j={Value=f.Default,Toggled=false,Mode=f.Mode or'Toggle',Type='Keybind',Callback=f.Callback or function(h)end,ChangedCallback=f.ChangedCallback or function(h)end},false,ac(aj.Element)(f.Title,f.Description,d.Container,true)ah.ApplyElementAPI(h,j,f,d.Context) local k=ai('TextLabel',{FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Regular,Enum.FontStyle.Normal),Text=f.Default,TextColor3=Color3.fromRGB(240,240,240),TextSize=13,TextXAlignment=Enum.TextXAlignment.Center,Size=UDim2.new(0,0,0,14),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=Color3.fromRGB(255,255,255),AutomaticSize=Enum.AutomaticSize.X,BackgroundTransparency=1,ThemeTag={TextColor3='Text'}})local l=ai('TextButton',{Size=UDim2.fromOffset(0,30),Position=UDim2.new(1,-10,0.5,0),AnchorPoint=Vector2.new(1,0.5),BackgroundTransparency=0.9,Parent=j.Frame,AutomaticSize=Enum.AutomaticSize.X,ThemeTag={BackgroundColor3='Keybind'}},{ai('UICorner',{CornerRadius=UDim.new(0,5)}),ai('UIPadding',{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)}),ai('UIStroke',{Transparency=0.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,ThemeTag={Color='InElementBorder'}}),k})function h.GetState(m)if af:GetFocusedTextBox()and h.Mode~='Always'then return false end if h.Mode=='Always'then return true elseif h.Mode=='Hold'then if h.Value=='None'then return false end local n=h.Value if n=='MouseLeft'or n=='MouseRight'then return n=='MouseLeft'and af:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)or n=='MouseRight'and af:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)else return af:IsKeyDown(Enum.KeyCode[h.Value])end else return h.Toggled end end function h.SetValue(m,n,o)n=n or h.Key o=o or h.Mode k.Text=n h.Value=n h.Mode=o end function h.OnClick(m,n)h.Clicked=n end function h.OnChanged(m,n)h.Changed=n n(h.Value)end function h.DoClick(m)g:SafeCallback(h.Callback,h.Toggled)g:SafeCallback(h.Clicked,h.Toggled)end function h.Destroy(m)j:Destroy()g.Options[e]=nil end ah.AddSignal(l.InputBegan,function(m)if j.Locked then return end if m.UserInputType==Enum.UserInputType.MouseButton1 or m.UserInputType==Enum.UserInputType.Touch then i=true k.Text='...'wait(0.2)local n n=af.InputBegan:Connect(function(o)local p if o.UserInputType==Enum.UserInputType.Keyboard then p=o.KeyCode.Name elseif o.UserInputType==Enum.UserInputType.MouseButton1 then p='MouseLeft'elseif o.UserInputType==Enum.UserInputType.MouseButton2 then p='MouseRight'end local s s=af.InputEnded:Connect(function(t)if t.KeyCode.Name==p or p=='MouseLeft'and t.UserInputType==Enum.UserInputType.MouseButton1 or p=='MouseRight'and t.UserInputType==Enum.UserInputType.MouseButton2 then i=false k.Text=p h.Value=p g:SafeCallback(h.ChangedCallback,t.KeyCode or t.UserInputType)g:SafeCallback(h.Changed,t.KeyCode or t.UserInputType)n:Disconnect()s:Disconnect()end end)end)end end)ah.AddSignal(af.InputBegan,function(m)if j.Locked then return end if not i and not af:GetFocusedTextBox()then if h.Mode=='Toggle'then local n=h.Value if n=='MouseLeft'or n=='MouseRight'then if n=='MouseLeft'and m.UserInputType==Enum.UserInputType.MouseButton1 or n=='MouseRight'and m.UserInputType==Enum.UserInputType.MouseButton2 then h.Toggled=not h.Toggled h:DoClick()end elseif m.UserInputType==Enum.UserInputType.Keyboard then if m.KeyCode.Name==n then h.Toggled=not h.Toggled h:DoClick()end end end end end)g.Options[e]=h return h end return c end,
[25]=function()
local aa,ab,ac,ad,ae=b(25)
local Root=ab.Parent.Parent
local Components=Root.Components
local Creator=ac(Root.Creator)

local Paragraph={}
Paragraph.__index=Paragraph
Paragraph.__type='Paragraph'

function Paragraph.New(self,config)
    assert(config.Title,'Paragraph - Missing Title')
    config.Content=config.Content or''
    local elem=ac(Components.Element)(config.Title,config.Content,self.Container,false)
    elem.Frame.BackgroundTransparency=0.92
    elem.Border.Transparency=0.6
    Creator.ApplyElementAPI(elem,elem,config,self.Context)
    return elem
end

return Paragraph
end,
[26]=function()
local aa,ab,ac,ad,ae=b(26)
local UserInputService=game:GetService'UserInputService'
local Root=ab.Parent.Parent
local Creator=ac(Root.Creator)
local New=Creator.New
local Components=Root.Components

local Slider={}
Slider.__index=Slider
Slider.__type='Slider'

function Slider.New(self,idx,config)
    local Library=self.Library
    assert(config.Title,'Slider - Missing Title.')
    assert(config.Default,'Slider - Missing default value.')
    assert(config.Min,'Slider - Missing minimum value.')
    assert(config.Max,'Slider - Missing maximum value.')
    assert(config.Rounding,'Slider - Missing rounding value.')

    local SliderObj={
        Value=nil,
        Min=config.Min,
        Max=config.Max,
        Rounding=config.Rounding,
        Callback=config.Callback or function()end,
        Type='Slider'
    }

    local dragging=false
    local Elem=ac(Components.Element)(config.Title,config.Description,self.Container,false)
    Elem.DescLabel.Size=UDim2.new(1,-170,0,14)
    Elem.OnLockChanged=function(locked)
        if locked then dragging=false end
    end
    Creator.ApplyElementAPI(SliderObj,Elem,config,self.Context)

    local Knob=New('ImageLabel',{
        AnchorPoint=Vector2.new(0,0.5),
        Position=UDim2.new(0,-7,0.5,0),
        Size=UDim2.fromOffset(14,14),
        Image='http://www.roblox.com/asset/?id=12266946128',
        ThemeTag={ImageColor3='Accent'}
    })

    local RailBounds=New('Frame',{
        BackgroundTransparency=1,
        Position=UDim2.fromOffset(7,0),
        Size=UDim2.new(1,-14,1,0)
    },{Knob})

    local FillBar=New('Frame',{
        Size=UDim2.new(0,0,1,0),
        ThemeTag={BackgroundColor3='Accent'}
    },{New('UICorner',{CornerRadius=UDim.new(1,0)})})

    local ValueText=New('TextLabel',{
        FontFace=Font.new'rbxasset://fonts/families/GothamSSm.json',
        Text='Value',
        TextSize=12,
        TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Right,
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BackgroundTransparency=1,
        Size=UDim2.new(0,100,0,14),
        Position=UDim2.new(0,-4,0.5,0),
        AnchorPoint=Vector2.new(1,0.5),
        ThemeTag={TextColor3='SubText'}
    })

    local RailContainer=New('Frame',{
        Size=UDim2.new(1,0,0,4),
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-10,0.5,0),
        BackgroundTransparency=0.4,
        Parent=Elem.Frame,
        ThemeTag={BackgroundColor3='SliderRail'}
    },{
        New('UICorner',{CornerRadius=UDim.new(1,0)}),
        New('UISizeConstraint',{MaxSize=Vector2.new(150,math.huge)}),
        ValueText,
        FillBar,
        RailBounds
    })

    local function UpdateFromInputX(xPos)
        local pct=math.clamp((xPos-RailBounds.AbsolutePosition.X)/math.max(RailBounds.AbsoluteSize.X,1),0,1)
        SliderObj:SetValue(SliderObj.Min+((SliderObj.Max-SliderObj.Min)*pct))
    end

    Creator.AddSignal(Knob.InputBegan,function(input)
        if Elem.Locked then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true
        end
    end)
    Creator.AddSignal(Knob.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end)
    Creator.AddSignal(RailContainer.InputBegan,function(input)
        if Elem.Locked then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true
            UpdateFromInputX(input.Position.X)
        end
    end)
    Creator.AddSignal(UserInputService.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end)
    Creator.AddSignal(UserInputService.InputChanged,function(input)
        if dragging and not Elem.Locked and(input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then
            UpdateFromInputX(input.Position.X)
        end
    end)

    function SliderObj.OnChanged(self,cb)
        SliderObj.Changed=cb
        cb(SliderObj.Value)
    end

    function SliderObj.SetValue(self,val)
        local num=tonumber(val)or SliderObj.Min
        self.Value=Library:Round(math.clamp(num,SliderObj.Min,SliderObj.Max),SliderObj.Rounding)
        local ratio=(self.Value-SliderObj.Min)/math.max(SliderObj.Max-SliderObj.Min,1E-6)
        Knob.Position=UDim2.new(ratio,-7,0.5,0)
        FillBar.Size=UDim2.fromScale(ratio,1)
        ValueText.Text=tostring(self.Value)
        Library:SafeCallback(SliderObj.Callback,self.Value)
        Library:SafeCallback(SliderObj.Changed,self.Value)
    end

    function SliderObj.Destroy(self)
        Elem:Destroy()
        Library.Options[idx]=nil
    end

    SliderObj:SetValue(config.Default)
    Library.Options[idx]=SliderObj
    return SliderObj
end

return Slider
end,
[27]=function()local aa,ab,ac,ad,ae=b(27)local af,ag=game:GetService'TweenService',ab.Parent.Parent local ah=ac(ag.Creator)local ai,aj,c=ah.New,ag.Components,{}c.__index=c c.__type='Toggle'function c.New(d,e,f)local g=d.Library assert(f.Title,'Toggle - Missing Title')local h,i={Value=f.Default or false,Callback=f.Callback or function(h)end,Type='Toggle'},ac(aj.Element)(f.Title,f.Description,d.Container,true)i.DescLabel.Size=UDim2.new(1,-54,0,14)ah.ApplyElementAPI(h,i,f,d.Context) local j,k=ai('ImageLabel',{AnchorPoint=Vector2.new(0,0.5),Size=UDim2.fromOffset(14,14),Position=UDim2.new(0,2,0.5,0),Image='http://www.roblox.com/asset/?id=12266946128',ImageTransparency=0.5,ThemeTag={ImageColor3='ToggleSlider'}}),ai('UIStroke',{Transparency=0.5,ThemeTag={Color='ToggleSlider'}})local l=ai('Frame',{Size=UDim2.fromOffset(36,18),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),Parent=i.Frame,BackgroundTransparency=1,ThemeTag={BackgroundColor3='Accent'}},{ai('UICorner',{CornerRadius=UDim.new(0,9)}),k,j})function h.OnChanged(m,n)h.Changed=n n(h.Value)end function h.SetValue(m,n)n=not not n h.Value=n ah.OverrideTag(k,{Color=h.Value and'Accent'or'ToggleSlider'})ah.OverrideTag(j,{ImageColor3=h.Value and'ToggleToggled'or'ToggleSlider'})af:Create(j,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.new(0,h.Value and 19 or 2,0.5,0)}):Play()af:Create(l,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency=h.Value and 0 or 1}):Play()j.ImageTransparency=h.Value and 0 or 0.5 g:SafeCallback(h.Callback,h.Value)g:SafeCallback(h.Changed,h.Value)end function h.Destroy(m)i:Destroy()g.Options[e]=nil end ah.AddSignal(i.Frame.MouseButton1Click,function()if i.Locked then return end h:SetValue(not h.Value)end)h:SetValue(h.Value)g.Options[e]=h return h end return c end,
[28]=function()local aa,ab,ac,ad,ae=b(28)return{assets={['lucide-accessibility']='rbxassetid://10709751939',['lucide-activity']='rbxassetid://10709752035',['lucide-air-vent']='rbxassetid://10709752131',['lucide-airplay']='rbxassetid://10709752254',['lucide-alarm-check']='rbxassetid://10709752405',['lucide-alarm-clock']='rbxassetid://10709752630',['lucide-alarm-clock-off']='rbxassetid://10709752508',['lucide-alarm-minus']='rbxassetid://10709752732',['lucide-alarm-plus']='rbxassetid://10709752825',['lucide-album']='rbxassetid://10709752906',['lucide-alert-circle']='rbxassetid://10709752996',['lucide-alert-octagon']='rbxassetid://10709753064',['lucide-alert-triangle']='rbxassetid://10709753149',['lucide-align-center']='rbxassetid://10709753570',['lucide-align-center-horizontal']='rbxassetid://10709753272',['lucide-align-center-vertical']='rbxassetid://10709753421',['lucide-align-end-horizontal']='rbxassetid://10709753692',['lucide-align-end-vertical']='rbxassetid://10709753808',['lucide-align-horizontal-distribute-center']='rbxassetid://10747779791',['lucide-align-horizontal-distribute-end']='rbxassetid://10747784534',['lucide-align-horizontal-distribute-start']='rbxassetid://10709754118',['lucide-align-horizontal-justify-center']='rbxassetid://10709754204',['lucide-align-horizontal-justify-end']='rbxassetid://10709754317',['lucide-align-horizontal-justify-start']='rbxassetid://10709754436',['lucide-align-horizontal-space-around']='rbxassetid://10709754590',['lucide-align-horizontal-space-between']='rbxassetid://10709754749',['lucide-align-justify']='rbxassetid://10709759610',['lucide-align-left']='rbxassetid://10709759764',['lucide-align-right']='rbxassetid://10709759895',['lucide-align-start-horizontal']='rbxassetid://10709760051',['lucide-align-start-vertical']='rbxassetid://10709760244',['lucide-align-vertical-distribute-center']='rbxassetid://10709760351',['lucide-align-vertical-distribute-end']='rbxassetid://10709760434',['lucide-align-vertical-distribute-start']='rbxassetid://10709760612',['lucide-align-vertical-justify-center']='rbxassetid://10709760814',['lucide-align-vertical-justify-end']='rbxassetid://10709761003',['lucide-align-vertical-justify-start']='rbxassetid://10709761176',['lucide-align-vertical-space-around']='rbxassetid://10709761324',['lucide-align-vertical-space-between']='rbxassetid://10709761434',['lucide-anchor']='rbxassetid://10709761530',['lucide-angry']='rbxassetid://10709761629',['lucide-annoyed']='rbxassetid://10709761722',['lucide-aperture']='rbxassetid://10709761813',['lucide-apple']='rbxassetid://10709761889',['lucide-archive']='rbxassetid://10709762233',['lucide-archive-restore']='rbxassetid://10709762058',['lucide-armchair']='rbxassetid://10709762327',['lucide-arrow-big-down']='rbxassetid://10747796644',['lucide-arrow-big-left']='rbxassetid://10709762574',['lucide-arrow-big-right']='rbxassetid://10709762727',['lucide-arrow-big-up']='rbxassetid://10709762879',['lucide-arrow-down']='rbxassetid://10709767827',['lucide-arrow-down-circle']='rbxassetid://10709763034',['lucide-arrow-down-left']='rbxassetid://10709767656',['lucide-arrow-down-right']='rbxassetid://10709767750',['lucide-arrow-left']='rbxassetid://10709768114',['lucide-arrow-left-circle']='rbxassetid://10709767936',['lucide-arrow-left-right']='rbxassetid://10709768019',['lucide-arrow-right']='rbxassetid://10709768347',['lucide-arrow-right-circle']='rbxassetid://10709768226',['lucide-arrow-up']='rbxassetid://10709768939',['lucide-arrow-up-circle']='rbxassetid://10709768432',['lucide-arrow-up-down']='rbxassetid://10709768538',['lucide-arrow-up-left']='rbxassetid://10709768661',['lucide-arrow-up-right']='rbxassetid://10709768787',['lucide-asterisk']='rbxassetid://10709769095',['lucide-at-sign']='rbxassetid://10709769286',['lucide-award']='rbxassetid://10709769406',['lucide-axe']='rbxassetid://10709769508',['lucide-axis-3d']='rbxassetid://10709769598',['lucide-baby']='rbxassetid://10709769732',['lucide-backpack']='rbxassetid://10709769841',['lucide-baggage-claim']='rbxassetid://10709769935',['lucide-banana']='rbxassetid://10709770005',['lucide-banknote']='rbxassetid://10709770178',['lucide-bar-chart']='rbxassetid://10709773755',['lucide-bar-chart-2']='rbxassetid://10709770317',['lucide-bar-chart-3']='rbxassetid://10709770431',['lucide-bar-chart-4']='rbxassetid://10709770560',['lucide-bar-chart-horizontal']='rbxassetid://10709773669',['lucide-barcode']='rbxassetid://10747360675',['lucide-baseline']='rbxassetid://10709773863',['lucide-bath']='rbxassetid://10709773963',['lucide-battery']='rbxassetid://10709774640',['lucide-battery-charging']='rbxassetid://10709774068',['lucide-battery-full']='rbxassetid://10709774206',['lucide-battery-low']='rbxassetid://10709774370',['lucide-battery-medium']='rbxassetid://10709774513',['lucide-beaker']='rbxassetid://10709774756',['lucide-bed']='rbxassetid://10709775036',['lucide-bed-double']='rbxassetid://10709774864',['lucide-bed-single']='rbxassetid://10709774968',['lucide-beer']='rbxassetid://10709775167',['lucide-bell']='rbxassetid://10709775704',['lucide-bell-minus']='rbxassetid://10709775241',['lucide-bell-off']='rbxassetid://10709775320',['lucide-bell-plus']='rbxassetid://10709775448',['lucide-bell-ring']='rbxassetid://10709775560',['lucide-bike']='rbxassetid://10709775894',['lucide-binary']='rbxassetid://10709776050',['lucide-bitcoin']='rbxassetid://10709776126',['lucide-bluetooth']='rbxassetid://10709776655',['lucide-bluetooth-connected']='rbxassetid://10709776240',['lucide-bluetooth-off']='rbxassetid://10709776344',['lucide-bluetooth-searching']='rbxassetid://10709776501',['lucide-bold']='rbxassetid://10747813908',['lucide-bomb']='rbxassetid://10709781460',['lucide-bone']='rbxassetid://10709781605',['lucide-book']='rbxassetid://10709781824',['lucide-book-open']='rbxassetid://10709781717',['lucide-bookmark']='rbxassetid://10709782154',['lucide-bookmark-minus']='rbxassetid://10709781919',['lucide-bookmark-plus']='rbxassetid://10709782044',['lucide-bot']='rbxassetid://10709782230',['lucide-box']='rbxassetid://10709782497',['lucide-box-select']='rbxassetid://10709782342',['lucide-boxes']='rbxassetid://10709782582',['lucide-briefcase']='rbxassetid://10709782662',['lucide-brush']='rbxassetid://10709782758',['lucide-bug']='rbxassetid://10709782845',['lucide-building']='rbxassetid://10709783051',['lucide-building-2']='rbxassetid://10709782939',['lucide-bus']='rbxassetid://10709783137',['lucide-cake']='rbxassetid://10709783217',['lucide-calculator']='rbxassetid://10709783311',['lucide-calendar']='rbxassetid://10709789505',['lucide-calendar-check']='rbxassetid://10709783474',['lucide-calendar-check-2']='rbxassetid://10709783392',['lucide-calendar-clock']='rbxassetid://10709783577',['lucide-calendar-days']='rbxassetid://10709783673',['lucide-calendar-heart']='rbxassetid://10709783835',['lucide-calendar-minus']='rbxassetid://10709783959',['lucide-calendar-off']='rbxassetid://10709788784',['lucide-calendar-plus']='rbxassetid://10709788937',['lucide-calendar-range']='rbxassetid://10709789053',['lucide-calendar-search']='rbxassetid://10709789200',['lucide-calendar-x']='rbxassetid://10709789407',['lucide-calendar-x-2']='rbxassetid://10709789329',['lucide-camera']='rbxassetid://10709789686',['lucide-camera-off']='rbxassetid://10747822677',['lucide-car']='rbxassetid://10709789810',['lucide-carrot']='rbxassetid://10709789960',['lucide-cast']='rbxassetid://10709790097',['lucide-charge']='rbxassetid://10709790202',['lucide-check']='rbxassetid://10709790644',['lucide-check-circle']='rbxassetid://10709790387',['lucide-check-circle-2']='rbxassetid://10709790298',['lucide-check-square']='rbxassetid://10709790537',['lucide-chef-hat']='rbxassetid://10709790757',['lucide-cherry']='rbxassetid://10709790875',['lucide-chevron-down']='rbxassetid://10709790948',['lucide-chevron-first']='rbxassetid://10709791015',['lucide-chevron-last']='rbxassetid://10709791130',['lucide-chevron-left']='rbxassetid://10709791281',['lucide-chevron-right']='rbxassetid://10709791437',['lucide-chevron-up']='rbxassetid://10709791523',['lucide-chevrons-down']='rbxassetid://10709796864',['lucide-chevrons-down-up']='rbxassetid://10709791632',['lucide-chevrons-left']='rbxassetid://10709797151',['lucide-chevrons-left-right']='rbxassetid://10709797006',['lucide-chevrons-right']='rbxassetid://10709797382',['lucide-chevrons-right-left']='rbxassetid://10709797274',['lucide-chevrons-up']='rbxassetid://10709797622',['lucide-chevrons-up-down']='rbxassetid://10709797508',['lucide-chrome']='rbxassetid://10709797725',['lucide-circle']='rbxassetid://10709798174',['lucide-circle-dot']='rbxassetid://10709797837',['lucide-circle-ellipsis']='rbxassetid://10709797985',['lucide-circle-slashed']='rbxassetid://10709798100',['lucide-citrus']='rbxassetid://10709798276',['lucide-clapperboard']='rbxassetid://10709798350',['lucide-clipboard']='rbxassetid://10709799288',['lucide-clipboard-check']='rbxassetid://10709798443',['lucide-clipboard-copy']='rbxassetid://10709798574',['lucide-clipboard-edit']='rbxassetid://10709798682',['lucide-clipboard-list']='rbxassetid://10709798792',['lucide-clipboard-signature']='rbxassetid://10709798890',['lucide-clipboard-type']='rbxassetid://10709798999',['lucide-clipboard-x']='rbxassetid://10709799124',['lucide-clock']='rbxassetid://10709805144',['lucide-clock-1']='rbxassetid://10709799535',['lucide-clock-10']='rbxassetid://10709799718',['lucide-clock-11']='rbxassetid://10709799818',['lucide-clock-12']='rbxassetid://10709799962',['lucide-clock-2']='rbxassetid://10709803876',['lucide-clock-3']='rbxassetid://10709803989',['lucide-clock-4']='rbxassetid://10709804164',['lucide-clock-5']='rbxassetid://10709804291',['lucide-clock-6']='rbxassetid://10709804435',['lucide-clock-7']='rbxassetid://10709804599',['lucide-clock-8']='rbxassetid://10709804784',['lucide-clock-9']='rbxassetid://10709804996',['lucide-cloud']='rbxassetid://10709806740',['lucide-cloud-cog']='rbxassetid://10709805262',['lucide-cloud-drizzle']='rbxassetid://10709805371',['lucide-cloud-fog']='rbxassetid://10709805477',['lucide-cloud-hail']='rbxassetid://10709805596',['lucide-cloud-lightning']='rbxassetid://10709805727',['lucide-cloud-moon']='rbxassetid://10709805942',['lucide-cloud-moon-rain']='rbxassetid://10709805838',['lucide-cloud-off']='rbxassetid://10709806060',['lucide-cloud-rain']='rbxassetid://10709806277',['lucide-cloud-rain-wind']='rbxassetid://10709806166',['lucide-cloud-snow']='rbxassetid://10709806374',['lucide-cloud-sun']='rbxassetid://10709806631',['lucide-cloud-sun-rain']='rbxassetid://10709806475',['lucide-cloudy']='rbxassetid://10709806859',['lucide-clover']='rbxassetid://10709806995',['lucide-code']='rbxassetid://10709810463',['lucide-code-2']='rbxassetid://10709807111',['lucide-codepen']='rbxassetid://10709810534',['lucide-codesandbox']='rbxassetid://10709810676',['lucide-coffee']='rbxassetid://10709810814',['lucide-cog']='rbxassetid://10709810948',['lucide-coins']='rbxassetid://10709811110',['lucide-columns']='rbxassetid://10709811261',['lucide-command']='rbxassetid://10709811365',['lucide-compass']='rbxassetid://10709811445',['lucide-component']='rbxassetid://10709811595',['lucide-concierge-bell']='rbxassetid://10709811706',['lucide-connection']='rbxassetid://10747361219',['lucide-contact']='rbxassetid://10709811834',['lucide-contrast']='rbxassetid://10709811939',['lucide-cookie']='rbxassetid://10709812067',['lucide-copy']='rbxassetid://10709812159',['lucide-copyleft']='rbxassetid://10709812251',['lucide-copyright']='rbxassetid://10709812311',['lucide-corner-down-left']='rbxassetid://10709812396',['lucide-corner-down-right']='rbxassetid://10709812485',['lucide-corner-left-down']='rbxassetid://10709812632',['lucide-corner-left-up']='rbxassetid://10709812784',['lucide-corner-right-down']='rbxassetid://10709812939',['lucide-corner-right-up']='rbxassetid://10709813094',['lucide-corner-up-left']='rbxassetid://10709813185',['lucide-corner-up-right']='rbxassetid://10709813281',['lucide-cpu']='rbxassetid://10709813383',['lucide-croissant']='rbxassetid://10709818125',['lucide-crop']='rbxassetid://10709818245',['lucide-cross']='rbxassetid://10709818399',['lucide-crosshair']='rbxassetid://10709818534',['lucide-crown']='rbxassetid://10709818626',['lucide-cup-soda']='rbxassetid://10709818763',['lucide-curly-braces']='rbxassetid://10709818847',['lucide-currency']='rbxassetid://10709818931',['lucide-database']='rbxassetid://10709818996',['lucide-delete']='rbxassetid://10709819059',['lucide-diamond']='rbxassetid://10709819149',['lucide-dice-1']='rbxassetid://10709819266',['lucide-dice-2']='rbxassetid://10709819361',['lucide-dice-3']='rbxassetid://10709819508',['lucide-dice-4']='rbxassetid://10709819670',['lucide-dice-5']='rbxassetid://10709819801',['lucide-dice-6']='rbxassetid://10709819896',['lucide-dices']='rbxassetid://10723343321',['lucide-diff']='rbxassetid://10723343416',['lucide-disc']='rbxassetid://10723343537',['lucide-divide']='rbxassetid://10723343805',['lucide-divide-circle']='rbxassetid://10723343636',['lucide-divide-square']='rbxassetid://10723343737',['lucide-dollar-sign']='rbxassetid://10723343958',['lucide-download']='rbxassetid://10723344270',['lucide-download-cloud']='rbxassetid://10723344088',['lucide-droplet']='rbxassetid://10723344432',['lucide-droplets']='rbxassetid://10734883356',['lucide-drumstick']='rbxassetid://10723344737',['lucide-edit']='rbxassetid://10734883598',['lucide-edit-2']='rbxassetid://10723344885',['lucide-edit-3']='rbxassetid://10723345088',['lucide-egg']='rbxassetid://10723345518',['lucide-egg-fried']='rbxassetid://10723345347',['lucide-electricity']='rbxassetid://10723345749',['lucide-electricity-off']='rbxassetid://10723345643',['lucide-equal']='rbxassetid://10723345990',['lucide-equal-not']='rbxassetid://10723345866',['lucide-eraser']='rbxassetid://10723346158',['lucide-euro']='rbxassetid://10723346372',['lucide-expand']='rbxassetid://10723346553',['lucide-external-link']='rbxassetid://10723346684',['lucide-eye']='rbxassetid://10723346959',['lucide-eye-off']='rbxassetid://10723346871',['lucide-factory']='rbxassetid://10723347051',['lucide-fan']='rbxassetid://10723354359',['lucide-fast-forward']='rbxassetid://10723354521',['lucide-feather']='rbxassetid://10723354671',['lucide-figma']='rbxassetid://10723354801',['lucide-file']='rbxassetid://10723374641',['lucide-file-archive']='rbxassetid://10723354921',['lucide-file-audio']='rbxassetid://10723355148',['lucide-file-audio-2']='rbxassetid://10723355026',['lucide-file-axis-3d']='rbxassetid://10723355272',['lucide-file-badge']='rbxassetid://10723355622',['lucide-file-badge-2']='rbxassetid://10723355451',['lucide-file-bar-chart']='rbxassetid://10723355887',['lucide-file-bar-chart-2']='rbxassetid://10723355746',['lucide-file-box']='rbxassetid://10723355989',['lucide-file-check']='rbxassetid://10723356210',['lucide-file-check-2']='rbxassetid://10723356100',['lucide-file-clock']='rbxassetid://10723356329',['lucide-file-code']='rbxassetid://10723356507',['lucide-file-cog']='rbxassetid://10723356830',['lucide-file-cog-2']='rbxassetid://10723356676',['lucide-file-diff']='rbxassetid://10723357039',['lucide-file-digit']='rbxassetid://10723357151',['lucide-file-down']='rbxassetid://10723357322',['lucide-file-edit']='rbxassetid://10723357495',['lucide-file-heart']='rbxassetid://10723357637',['lucide-file-image']='rbxassetid://10723357790',['lucide-file-input']='rbxassetid://10723357933',['lucide-file-json']='rbxassetid://10723364435',['lucide-file-json-2']='rbxassetid://10723364361',['lucide-file-key']='rbxassetid://10723364605',['lucide-file-key-2']='rbxassetid://10723364515',['lucide-file-line-chart']='rbxassetid://10723364725',['lucide-file-lock']='rbxassetid://10723364957',['lucide-file-lock-2']='rbxassetid://10723364861',['lucide-file-minus']='rbxassetid://10723365254',['lucide-file-minus-2']='rbxassetid://10723365086',['lucide-file-output']='rbxassetid://10723365457',['lucide-file-pie-chart']='rbxassetid://10723365598',['lucide-file-plus']='rbxassetid://10723365877',['lucide-file-plus-2']='rbxassetid://10723365766',['lucide-file-question']='rbxassetid://10723365987',['lucide-file-scan']='rbxassetid://10723366167',['lucide-file-search']='rbxassetid://10723366550',['lucide-file-search-2']='rbxassetid://10723366340',['lucide-file-signature']='rbxassetid://10723366741',['lucide-file-spreadsheet']='rbxassetid://10723366962',['lucide-file-symlink']='rbxassetid://10723367098',['lucide-file-terminal']='rbxassetid://10723367244',['lucide-file-text']='rbxassetid://10723367380',['lucide-file-type']='rbxassetid://10723367606',['lucide-file-type-2']='rbxassetid://10723367509',['lucide-file-up']='rbxassetid://10723367734',['lucide-file-video']='rbxassetid://10723373884',['lucide-file-video-2']='rbxassetid://10723367834',['lucide-file-volume']='rbxassetid://10723374172',['lucide-file-volume-2']='rbxassetid://10723374030',['lucide-file-warning']='rbxassetid://10723374276',['lucide-file-x']='rbxassetid://10723374544',['lucide-file-x-2']='rbxassetid://10723374378',['lucide-files']='rbxassetid://10723374759',['lucide-film']='rbxassetid://10723374981',['lucide-filter']='rbxassetid://10723375128',['lucide-fingerprint']='rbxassetid://10723375250',['lucide-flag']='rbxassetid://10723375890',['lucide-flag-off']='rbxassetid://10723375443',['lucide-flag-triangle-left']='rbxassetid://10723375608',['lucide-flag-triangle-right']='rbxassetid://10723375727',['lucide-flame']='rbxassetid://10723376114',['lucide-flashlight']='rbxassetid://10723376471',['lucide-flashlight-off']='rbxassetid://10723376365',['lucide-flask-conical']='rbxassetid://10734883986',['lucide-flask-round']='rbxassetid://10723376614',['lucide-flip-horizontal']='rbxassetid://10723376884',['lucide-flip-horizontal-2']='rbxassetid://10723376745',['lucide-flip-vertical']='rbxassetid://10723377138',['lucide-flip-vertical-2']='rbxassetid://10723377026',['lucide-flower']='rbxassetid://10747830374',['lucide-flower-2']='rbxassetid://10723377305',['lucide-focus']='rbxassetid://10723377537',['lucide-folder']='rbxassetid://10723387563',['lucide-folder-archive']='rbxassetid://10723384478',['lucide-folder-check']='rbxassetid://10723384605',['lucide-folder-clock']='rbxassetid://10723384731',['lucide-folder-closed']='rbxassetid://10723384893',['lucide-folder-cog']='rbxassetid://10723385213',['lucide-folder-cog-2']='rbxassetid://10723385036',['lucide-folder-down']='rbxassetid://10723385338',['lucide-folder-edit']='rbxassetid://10723385445',['lucide-folder-heart']='rbxassetid://10723385545',['lucide-folder-input']='rbxassetid://10723385721',['lucide-folder-key']='rbxassetid://10723385848',['lucide-folder-lock']='rbxassetid://10723386005',['lucide-folder-minus']='rbxassetid://10723386127',['lucide-folder-open']='rbxassetid://10723386277',['lucide-folder-output']='rbxassetid://10723386386',['lucide-folder-plus']='rbxassetid://10723386531',['lucide-folder-search']='rbxassetid://10723386787',['lucide-folder-search-2']='rbxassetid://10723386674',['lucide-folder-symlink']='rbxassetid://10723386930',['lucide-folder-tree']='rbxassetid://10723387085',['lucide-folder-up']='rbxassetid://10723387265',['lucide-folder-x']='rbxassetid://10723387448',['lucide-folders']='rbxassetid://10723387721',['lucide-form-input']='rbxassetid://10723387841',['lucide-forward']='rbxassetid://10723388016',['lucide-frame']='rbxassetid://10723394389',['lucide-framer']='rbxassetid://10723394565',['lucide-frown']='rbxassetid://10723394681',['lucide-fuel']='rbxassetid://10723394846',['lucide-function-square']='rbxassetid://10723395041',['lucide-gamepad']='rbxassetid://10723395457',['lucide-gamepad-2']='rbxassetid://10723395215',['lucide-gauge']='rbxassetid://10723395708',['lucide-gavel']='rbxassetid://10723395896',['lucide-gem']='rbxassetid://10723396000',['lucide-ghost']='rbxassetid://10723396107',['lucide-gift']='rbxassetid://10723396402',['lucide-gift-card']='rbxassetid://10723396225',['lucide-git-branch']='rbxassetid://10723396676',['lucide-git-branch-plus']='rbxassetid://10723396542',['lucide-git-commit']='rbxassetid://10723396812',['lucide-git-compare']='rbxassetid://10723396954',['lucide-git-fork']='rbxassetid://10723397049',['lucide-git-merge']='rbxassetid://10723397165',['lucide-git-pull-request']='rbxassetid://10723397431',['lucide-git-pull-request-closed']='rbxassetid://10723397268',['lucide-git-pull-request-draft']='rbxassetid://10734884302',['lucide-glass']='rbxassetid://10723397788',['lucide-glass-2']='rbxassetid://10723397529',['lucide-glass-water']='rbxassetid://10723397678',['lucide-glasses']='rbxassetid://10723397895',['lucide-globe']='rbxassetid://10723404337',['lucide-globe-2']='rbxassetid://10723398002',['lucide-grab']='rbxassetid://10723404472',['lucide-graduation-cap']='rbxassetid://10723404691',['lucide-grape']='rbxassetid://10723404822',['lucide-grid']='rbxassetid://10723404936',['lucide-grip-horizontal']='rbxassetid://10723405089',['lucide-grip-vertical']='rbxassetid://10723405236',['lucide-hammer']='rbxassetid://10723405360',['lucide-hand']='rbxassetid://10723405649',['lucide-hand-metal']='rbxassetid://10723405508',['lucide-hard-drive']='rbxassetid://10723405749',['lucide-hard-hat']='rbxassetid://10723405859',['lucide-hash']='rbxassetid://10723405975',['lucide-haze']='rbxassetid://10723406078',['lucide-headphones']='rbxassetid://10723406165',['lucide-heart']='rbxassetid://10723406885',['lucide-heart-crack']='rbxassetid://10723406299',['lucide-heart-handshake']='rbxassetid://10723406480',['lucide-heart-off']='rbxassetid://10723406662',['lucide-heart-pulse']='rbxassetid://10723406795',['lucide-help-circle']='rbxassetid://10723406988',['lucide-hexagon']='rbxassetid://10723407092',['lucide-highlighter']='rbxassetid://10723407192',['lucide-history']='rbxassetid://10723407335',['lucide-home']='rbxassetid://10723407389',['lucide-hourglass']='rbxassetid://10723407498',['lucide-ice-cream']='rbxassetid://10723414308',['lucide-image']='rbxassetid://10723415040',['lucide-image-minus']='rbxassetid://10723414487',['lucide-image-off']='rbxassetid://10723414677',['lucide-image-plus']='rbxassetid://10723414827',['lucide-import']='rbxassetid://10723415205',['lucide-inbox']='rbxassetid://10723415335',['lucide-indent']='rbxassetid://10723415494',['lucide-indian-rupee']='rbxassetid://10723415642',['lucide-infinity']='rbxassetid://10723415766',['lucide-info']='rbxassetid://10723415903',['lucide-inspect']='rbxassetid://10723416057',['lucide-italic']='rbxassetid://10723416195',['lucide-japanese-yen']='rbxassetid://10723416363',['lucide-joystick']='rbxassetid://10723416527',['lucide-key']='rbxassetid://10723416652',['lucide-keyboard']='rbxassetid://10723416765',['lucide-lamp']='rbxassetid://10723417513',['lucide-lamp-ceiling']='rbxassetid://10723416922',['lucide-lamp-desk']='rbxassetid://10723417016',['lucide-lamp-floor']='rbxassetid://10723417131',['lucide-lamp-wall-down']='rbxassetid://10723417240',['lucide-lamp-wall-up']='rbxassetid://10723417356',['lucide-landmark']='rbxassetid://10723417608',['lucide-languages']='rbxassetid://10723417703',['lucide-laptop']='rbxassetid://10723423881',['lucide-laptop-2']='rbxassetid://10723417797',['lucide-lasso']='rbxassetid://10723424235',['lucide-lasso-select']='rbxassetid://10723424058',['lucide-laugh']='rbxassetid://10723424372',['lucide-layers']='rbxassetid://10723424505',['lucide-layout']='rbxassetid://10723425376',['lucide-layout-dashboard']='rbxassetid://10723424646',['lucide-layout-grid']='rbxassetid://10723424838',['lucide-layout-list']='rbxassetid://10723424963',['lucide-layout-template']='rbxassetid://10723425187',['lucide-leaf']='rbxassetid://10723425539',['lucide-library']='rbxassetid://10723425615',['lucide-life-buoy']='rbxassetid://10723425685',['lucide-lightbulb']='rbxassetid://10723425852',['lucide-lightbulb-off']='rbxassetid://10723425762',['lucide-line-chart']='rbxassetid://10723426393',['lucide-link']='rbxassetid://10723426722',['lucide-link-2']='rbxassetid://10723426595',['lucide-link-2-off']='rbxassetid://10723426513',['lucide-list']='rbxassetid://10723433811',['lucide-list-checks']='rbxassetid://10734884548',['lucide-list-end']='rbxassetid://10723426886',['lucide-list-minus']='rbxassetid://10723426986',['lucide-list-music']='rbxassetid://10723427081',['lucide-list-ordered']='rbxassetid://10723427199',['lucide-list-plus']='rbxassetid://10723427334',['lucide-list-start']='rbxassetid://10723427494',['lucide-list-video']='rbxassetid://10723427619',['lucide-list-x']='rbxassetid://10723433655',['lucide-loader']='rbxassetid://10723434070',['lucide-loader-2']='rbxassetid://10723433935',['lucide-locate']='rbxassetid://10723434557',['lucide-locate-fixed']='rbxassetid://10723434236',['lucide-locate-off']='rbxassetid://10723434379',['lucide-lock']='rbxassetid://10723434711',['lucide-log-in']='rbxassetid://10723434830',['lucide-log-out']='rbxassetid://10723434906',['lucide-luggage']='rbxassetid://10723434993',['lucide-magnet']='rbxassetid://10723435069',['lucide-mail']='rbxassetid://10734885430',['lucide-mail-check']='rbxassetid://10723435182',['lucide-mail-minus']='rbxassetid://10723435261',['lucide-mail-open']='rbxassetid://10723435342',['lucide-mail-plus']='rbxassetid://10723435443',['lucide-mail-question']='rbxassetid://10723435515',['lucide-mail-search']='rbxassetid://10734884739',['lucide-mail-warning']='rbxassetid://10734885015',['lucide-mail-x']='rbxassetid://10734885247',['lucide-mails']='rbxassetid://10734885614',['lucide-map']='rbxassetid://10734886202',['lucide-map-pin']='rbxassetid://10734886004',['lucide-map-pin-off']='rbxassetid://10734885803',['lucide-maximize']='rbxassetid://10734886735',['lucide-maximize-2']='rbxassetid://10734886496',['lucide-medal']='rbxassetid://10734887072',['lucide-megaphone']='rbxassetid://10734887454',['lucide-megaphone-off']='rbxassetid://10734887311',['lucide-meh']='rbxassetid://10734887603',['lucide-menu']='rbxassetid://10734887784',['lucide-message-circle']='rbxassetid://10734888000',['lucide-message-square']='rbxassetid://10734888228',['lucide-mic']='rbxassetid://10734888864',['lucide-mic-2']='rbxassetid://10734888430',['lucide-mic-off']='rbxassetid://10734888646',['lucide-microscope']='rbxassetid://10734889106',['lucide-microwave']='rbxassetid://10734895076',['lucide-milestone']='rbxassetid://10734895310',['lucide-minimize']='rbxassetid://10734895698',['lucide-minimize-2']='rbxassetid://10734895530',['lucide-minus']='rbxassetid://10734896206',['lucide-minus-circle']='rbxassetid://10734895856',['lucide-minus-square']='rbxassetid://10734896029',['lucide-monitor']='rbxassetid://10734896881',['lucide-monitor-off']='rbxassetid://10734896360',['lucide-monitor-speaker']='rbxassetid://10734896512',['lucide-moon']='rbxassetid://10734897102',['lucide-more-horizontal']='rbxassetid://10734897250',['lucide-more-vertical']='rbxassetid://10734897387',['lucide-mountain']='rbxassetid://10734897956',['lucide-mountain-snow']='rbxassetid://10734897665',['lucide-mouse']='rbxassetid://10734898592',['lucide-mouse-pointer']='rbxassetid://10734898476',['lucide-mouse-pointer-2']='rbxassetid://10734898194',['lucide-mouse-pointer-click']='rbxassetid://10734898355',['lucide-move']='rbxassetid://10734900011',['lucide-move-3d']='rbxassetid://10734898756',['lucide-move-diagonal']='rbxassetid://10734899164',['lucide-move-diagonal-2']='rbxassetid://10734898934',['lucide-move-horizontal']='rbxassetid://10734899414',['lucide-move-vertical']='rbxassetid://10734899821',['lucide-music']='rbxassetid://10734905958',['lucide-music-2']='rbxassetid://10734900215',['lucide-music-3']='rbxassetid://10734905665',['lucide-music-4']='rbxassetid://10734905823',['lucide-navigation']='rbxassetid://10734906744',['lucide-navigation-2']='rbxassetid://10734906332',['lucide-navigation-2-off']='rbxassetid://10734906144',['lucide-navigation-off']='rbxassetid://10734906580',['lucide-network']='rbxassetid://10734906975',['lucide-newspaper']='rbxassetid://10734907168',['lucide-octagon']='rbxassetid://10734907361',['lucide-option']='rbxassetid://10734907649',['lucide-outdent']='rbxassetid://10734907933',['lucide-package']='rbxassetid://10734909540',['lucide-package-2']='rbxassetid://10734908151',['lucide-package-check']='rbxassetid://10734908384',['lucide-package-minus']='rbxassetid://10734908626',['lucide-package-open']='rbxassetid://10734908793',['lucide-package-plus']='rbxassetid://10734909016',['lucide-package-search']='rbxassetid://10734909196',['lucide-package-x']='rbxassetid://10734909375',['lucide-paint-bucket']='rbxassetid://10734909847',['lucide-paintbrush']='rbxassetid://10734910187',['lucide-paintbrush-2']='rbxassetid://10734910030',['lucide-palette']='rbxassetid://10734910430',['lucide-palmtree']='rbxassetid://10734910680',['lucide-paperclip']='rbxassetid://10734910927',['lucide-party-popper']='rbxassetid://10734918735',['lucide-pause']='rbxassetid://10734919336',['lucide-pause-circle']='rbxassetid://10735024209',['lucide-pause-octagon']='rbxassetid://10734919143',['lucide-pen-tool']='rbxassetid://10734919503',['lucide-pencil']='rbxassetid://10734919691',['lucide-percent']='rbxassetid://10734919919',['lucide-person-standing']='rbxassetid://10734920149',['lucide-phone']='rbxassetid://10734921524',['lucide-phone-call']='rbxassetid://10734920305',['lucide-phone-forwarded']='rbxassetid://10734920508',['lucide-phone-incoming']='rbxassetid://10734920694',['lucide-phone-missed']='rbxassetid://10734920845',['lucide-phone-off']='rbxassetid://10734921077',['lucide-phone-outgoing']='rbxassetid://10734921288',['lucide-pie-chart']='rbxassetid://10734921727',['lucide-piggy-bank']='rbxassetid://10734921935',['lucide-pin']='rbxassetid://10734922324',['lucide-pin-off']='rbxassetid://10734922180',['lucide-pipette']='rbxassetid://10734922497',['lucide-pizza']='rbxassetid://10734922774',['lucide-plane']='rbxassetid://10734922971',['lucide-play']='rbxassetid://10734923549',['lucide-play-circle']='rbxassetid://10734923214',['lucide-plus']='rbxassetid://10734924532',['lucide-plus-circle']='rbxassetid://10734923868',['lucide-plus-square']='rbxassetid://10734924219',['lucide-podcast']='rbxassetid://10734929553',['lucide-pointer']='rbxassetid://10734929723',['lucide-pound-sterling']='rbxassetid://10734929981',['lucide-power']='rbxassetid://10734930466',['lucide-power-off']='rbxassetid://10734930257',['lucide-printer']='rbxassetid://10734930632',['lucide-puzzle']='rbxassetid://10734930886',['lucide-quote']='rbxassetid://10734931234',['lucide-radio']='rbxassetid://10734931596',['lucide-radio-receiver']='rbxassetid://10734931402',['lucide-rectangle-horizontal']='rbxassetid://10734931777',['lucide-rectangle-vertical']='rbxassetid://10734932081',['lucide-recycle']='rbxassetid://10734932295',['lucide-redo']='rbxassetid://10734932822',['lucide-redo-2']='rbxassetid://10734932586',['lucide-refresh-ccw']='rbxassetid://10734933056',['lucide-refresh-cw']='rbxassetid://10734933222',['lucide-refrigerator']='rbxassetid://10734933465',['lucide-regex']='rbxassetid://10734933655',['lucide-repeat']='rbxassetid://10734933966',['lucide-repeat-1']='rbxassetid://10734933826',['lucide-reply']='rbxassetid://10734934252',['lucide-reply-all']='rbxassetid://10734934132',['lucide-rewind']='rbxassetid://10734934347',['lucide-rocket']='rbxassetid://10734934585',['lucide-rocking-chair']='rbxassetid://10734939942',['lucide-rotate-3d']='rbxassetid://10734940107',['lucide-rotate-ccw']='rbxassetid://10734940376',['lucide-rotate-cw']='rbxassetid://10734940654',['lucide-rss']='rbxassetid://10734940825',['lucide-ruler']='rbxassetid://10734941018',['lucide-russian-ruble']='rbxassetid://10734941199',['lucide-sailboat']='rbxassetid://10734941354',['lucide-save']='rbxassetid://10734941499',['lucide-scale']='rbxassetid://10734941912',['lucide-scale-3d']='rbxassetid://10734941739',['lucide-scaling']='rbxassetid://10734942072',['lucide-scan']='rbxassetid://10734942565',['lucide-scan-face']='rbxassetid://10734942198',['lucide-scan-line']='rbxassetid://10734942351',['lucide-scissors']='rbxassetid://10734942778',['lucide-screen-share']='rbxassetid://10734943193',['lucide-screen-share-off']='rbxassetid://10734942967',['lucide-scroll']='rbxassetid://10734943448',['lucide-search']='rbxassetid://10734943674',['lucide-send']='rbxassetid://10734943902',['lucide-separator-horizontal']='rbxassetid://10734944115',['lucide-separator-vertical']='rbxassetid://10734944326',['lucide-server']='rbxassetid://10734949856',['lucide-server-cog']='rbxassetid://10734944444',['lucide-server-crash']='rbxassetid://10734944554',['lucide-server-off']='rbxassetid://10734944668',['lucide-settings']='rbxassetid://10734950309',['lucide-settings-2']='rbxassetid://10734950020',['lucide-share']='rbxassetid://10734950813',['lucide-share-2']='rbxassetid://10734950553',['lucide-sheet']='rbxassetid://10734951038',['lucide-shield']='rbxassetid://10734951847',['lucide-shield-alert']='rbxassetid://10734951173',['lucide-shield-check']='rbxassetid://10734951367',['lucide-shield-close']='rbxassetid://10734951535',['lucide-shield-off']='rbxassetid://10734951684',['lucide-shirt']='rbxassetid://10734952036',['lucide-shopping-bag']='rbxassetid://10734952273',['lucide-shopping-cart']='rbxassetid://10734952479',['lucide-shovel']='rbxassetid://10734952773',['lucide-shower-head']='rbxassetid://10734952942',['lucide-shrink']='rbxassetid://10734953073',['lucide-shrub']='rbxassetid://10734953241',['lucide-shuffle']='rbxassetid://10734953451',['lucide-sidebar']='rbxassetid://10734954301',['lucide-sidebar-close']='rbxassetid://10734953715',['lucide-sidebar-open']='rbxassetid://10734954000',['lucide-sigma']='rbxassetid://10734954538',['lucide-signal']='rbxassetid://10734961133',['lucide-signal-high']='rbxassetid://10734954807',['lucide-signal-low']='rbxassetid://10734955080',['lucide-signal-medium']='rbxassetid://10734955336',['lucide-signal-zero']='rbxassetid://10734960878',['lucide-siren']='rbxassetid://10734961284',['lucide-skip-back']='rbxassetid://10734961526',['lucide-skip-forward']='rbxassetid://10734961809',['lucide-skull']='rbxassetid://10734962068',['lucide-slack']='rbxassetid://10734962339',['lucide-slash']='rbxassetid://10734962600',['lucide-slice']='rbxassetid://10734963024',['lucide-sliders']='rbxassetid://10734963400',['lucide-sliders-horizontal']='rbxassetid://10734963191',['lucide-smartphone']='rbxassetid://10734963940',['lucide-smartphone-charging']='rbxassetid://10734963671',['lucide-smile']='rbxassetid://10734964441',['lucide-smile-plus']='rbxassetid://10734964188',['lucide-snowflake']='rbxassetid://10734964600',['lucide-sofa']='rbxassetid://10734964852',['lucide-sort-asc']='rbxassetid://10734965115',['lucide-sort-desc']='rbxassetid://10734965287',['lucide-speaker']='rbxassetid://10734965419',['lucide-sprout']='rbxassetid://10734965572',['lucide-square']='rbxassetid://10734965702',['lucide-star']='rbxassetid://10734966248',['lucide-star-half']='rbxassetid://10734965897',['lucide-star-off']='rbxassetid://10734966097',['lucide-stethoscope']='rbxassetid://10734966384',['lucide-sticker']='rbxassetid://10734972234',['lucide-sticky-note']='rbxassetid://10734972463',['lucide-stop-circle']='rbxassetid://10734972621',['lucide-stretch-horizontal']='rbxassetid://10734972862',['lucide-stretch-vertical']='rbxassetid://10734973130',['lucide-strikethrough']='rbxassetid://10734973290',['lucide-subscript']='rbxassetid://10734973457',['lucide-sun']='rbxassetid://10734974297',['lucide-sun-dim']='rbxassetid://10734973645',['lucide-sun-medium']='rbxassetid://10734973778',['lucide-sun-moon']='rbxassetid://10734973999',['lucide-sun-snow']='rbxassetid://10734974130',['lucide-sunrise']='rbxassetid://10734974522',['lucide-sunset']='rbxassetid://10734974689',['lucide-superscript']='rbxassetid://10734974850',['lucide-swiss-franc']='rbxassetid://10734975024',['lucide-switch-camera']='rbxassetid://10734975214',['lucide-sword']='rbxassetid://10734975486',['lucide-swords']='rbxassetid://10734975692',['lucide-syringe']='rbxassetid://10734975932',['lucide-table']='rbxassetid://10734976230',['lucide-table-2']='rbxassetid://10734976097',['lucide-tablet']='rbxassetid://10734976394',['lucide-tag']='rbxassetid://10734976528',['lucide-tags']='rbxassetid://10734976739',['lucide-target']='rbxassetid://10734977012',['lucide-tent']='rbxassetid://10734981750',['lucide-terminal']='rbxassetid://10734982144',['lucide-terminal-square']='rbxassetid://10734981995',['lucide-text-cursor']='rbxassetid://10734982395',['lucide-text-cursor-input']='rbxassetid://10734982297',['lucide-thermometer']='rbxassetid://10734983134',['lucide-thermometer-snowflake']='rbxassetid://10734982571',['lucide-thermometer-sun']='rbxassetid://10734982771',['lucide-thumbs-down']='rbxassetid://10734983359',['lucide-thumbs-up']='rbxassetid://10734983629',['lucide-ticket']='rbxassetid://10734983868',['lucide-timer']='rbxassetid://10734984606',['lucide-timer-off']='rbxassetid://10734984138',['lucide-timer-reset']='rbxassetid://10734984355',['lucide-toggle-left']='rbxassetid://10734984834',['lucide-toggle-right']='rbxassetid://10734985040',['lucide-tornado']='rbxassetid://10734985247',['lucide-toy-brick']='rbxassetid://10747361919',['lucide-train']='rbxassetid://10747362105',['lucide-trash']='rbxassetid://10747362393',['lucide-trash-2']='rbxassetid://10747362241',['lucide-tree-deciduous']='rbxassetid://10747362534',['lucide-tree-pine']='rbxassetid://10747362748',['lucide-trees']='rbxassetid://10747363016',['lucide-trending-down']='rbxassetid://10747363205',['lucide-trending-up']='rbxassetid://10747363465',['lucide-triangle']='rbxassetid://10747363621',['lucide-trophy']='rbxassetid://10747363809',['lucide-truck']='rbxassetid://10747364031',['lucide-tv']='rbxassetid://10747364593',['lucide-tv-2']='rbxassetid://10747364302',['lucide-type']='rbxassetid://10747364761',['lucide-umbrella']='rbxassetid://10747364971',['lucide-underline']='rbxassetid://10747365191',['lucide-undo']='rbxassetid://10747365484',['lucide-undo-2']='rbxassetid://10747365359',['lucide-unlink']='rbxassetid://10747365771',['lucide-unlink-2']='rbxassetid://10747397871',['lucide-unlock']='rbxassetid://10747366027',['lucide-upload']='rbxassetid://10747366434',['lucide-upload-cloud']='rbxassetid://10747366266',['lucide-usb']='rbxassetid://10747366606',['lucide-user']='rbxassetid://10747373176',['lucide-user-check']='rbxassetid://10747371901',['lucide-user-cog']='rbxassetid://10747372167',['lucide-user-minus']='rbxassetid://10747372346',['lucide-user-plus']='rbxassetid://10747372702',['lucide-user-x']='rbxassetid://10747372992',['lucide-users']='rbxassetid://10747373426',['lucide-utensils']='rbxassetid://10747373821',['lucide-utensils-crossed']='rbxassetid://10747373629',['lucide-venetian-mask']='rbxassetid://10747374003',['lucide-verified']='rbxassetid://10747374131',['lucide-vibrate']='rbxassetid://10747374489',['lucide-vibrate-off']='rbxassetid://10747374269',['lucide-video']='rbxassetid://10747374938',['lucide-video-off']='rbxassetid://10747374721',['lucide-view']='rbxassetid://10747375132',['lucide-voicemail']='rbxassetid://10747375281',['lucide-volume']='rbxassetid://10747376008',['lucide-volume-1']='rbxassetid://10747375450',['lucide-volume-2']='rbxassetid://10747375679',['lucide-volume-x']='rbxassetid://10747375880',['lucide-wallet']='rbxassetid://10747376205',['lucide-wand']='rbxassetid://10747376565',['lucide-wand-2']='rbxassetid://10747376349',['lucide-watch']='rbxassetid://10747376722',['lucide-waves']='rbxassetid://10747376931',['lucide-webcam']='rbxassetid://10747381992',['lucide-wifi']='rbxassetid://10747382504',['lucide-wifi-off']='rbxassetid://10747382268',['lucide-wind']='rbxassetid://10747382750',['lucide-wrap-text']='rbxassetid://10747383065',['lucide-wrench']='rbxassetid://10747383470',['lucide-x']='rbxassetid://10747384394',['lucide-x-circle']='rbxassetid://10747383819',['lucide-x-octagon']='rbxassetid://10747384037',['lucide-x-square']='rbxassetid://10747384217',['lucide-zoom-in']='rbxassetid://10747384552',['lucide-zoom-out']='rbxassetid://10747384679'}}end,
[30]=function()local aa,ab,ac,ad,ae=b(30)local af={SingleMotor=ac(ab.SingleMotor),GroupMotor=ac(ab.GroupMotor),Instant=ac(ab.Instant),Linear=ac(ab.Linear),Spring=ac(ab.Spring),isMotor=ac(ab.isMotor)}return af end,
[31]=function()local aa,ab,ac,ad,ae=b(31)local af,ag,ah,ai,am=game:GetService'RunService',ac(ab.Parent.Signal),function()end,{},{}ai.__index=ai function ai.new()return setmetatable({_onStep=ag.new(),_onStart=ag.new(),_onComplete=ag.new()},ai)end function ai.onStep(aj,c)return aj._onStep:connect(c)end function ai.onStart(aj,c)return aj._onStart:connect(c)end function ai.onComplete(aj,c)return aj._onComplete:connect(c)end function ai.start(aj)if not aj._connection then am[aj]=true aj._connection=af.RenderStepped:Connect(function(c)if setthreadidentity then pcall(setthreadidentity,8)end local ok=pcall(aj.step,aj,c)if not ok then aj:stop()end end)end end function ai.stop(aj)am[aj]=nil if aj._connection then pcall(function()aj._connection:Disconnect()end)aj._connection=nil end end function ai.stopAll()for aj in pairs(am)do aj:stop()end end ai.destroy=ai.stop ai.step=ah ai.getValue=ah ai.setGoal=ah function ai.__tostring(aj)return'Motor'end return ai end,
[32]=function()local aa,ab,ac,ad,ae=b(32)return function()local af,ag=game:GetService'RunService',ac(ab.Parent.BaseMotor)describe('connection management',function()local ah=ag.new()it('should hook up connections on :start()',function()ah:start()expect(typeof(ah._connection)).to.equal'RBXScriptConnection'end)it('should remove connections on :stop() or :destroy()',function()ah:stop()expect(ah._connection).to.equal(nil)end)end)it('should call :step() with deltaTime',function()local ah,ai=(ag.new())function ah.step(aj,...)ai={...}ah:stop()end ah:start()local aj=af.RenderStepped:Wait()af.RenderStepped:Wait()expect(ai).to.be.ok()expect(ai[1]).to.equal(aj)end)end end,
[33]=function()local aa,ab,ac,ad,ae=b(33)local af,ag,ah=ac(ab.Parent.BaseMotor),ac(ab.Parent.SingleMotor),ac(ab.Parent.isMotor)local ai=setmetatable({},af)ai.__index=ai local aj=function(aj)if ah(aj)then return aj end local c=typeof(aj)if c=='number'then return ag.new(aj,false)elseif c=='table'then return ai.new(aj,false)end error(('Unable to convert %q to motor; type %s is unsupported'):format(aj,c),2)end function ai.new(c,d)assert(c,'Missing argument #1: initialValues')assert(typeof(c)=='table','initialValues must be a table!')assert(not c.step,[[initialValues contains disallowed property "step". Did you mean to put a table of values here?]])local e=setmetatable(af.new(),ai)if d~=nil then e._useImplicitConnections=d else e._useImplicitConnections=true end e._complete=true e._motors={}for f,g in pairs(c)do e._motors[f]=aj(g)end return e end function ai.step(c,d)if c._complete then return true end local e=true for f,g in pairs(c._motors)do local h=g:step(d)if not h then e=false end end c._onStep:fire(c:getValue())if e then if c._useImplicitConnections then c:stop()end c._complete=true c._onComplete:fire()end return e end function ai.setGoal(c,d)assert(not d.step,[[goals contains disallowed property "step". Did you mean to put a table of goals here?]])c._complete=false c._onStart:fire()for e,f in pairs(d)do local g=assert(c._motors[e],('Unknown motor for key %s'):format(e))g:setGoal(f)end if c._useImplicitConnections then c:start()end end function ai.getValue(c)local d={}for e,f in pairs(c._motors)do d[e]=f:getValue()end return d end function ai.__tostring(c)return'Motor(Group)'end return ai end,
[34]=function()local aa,ab,ac,ad,ae=b(34)return function()local af,ag,ah=ac(ab.Parent.GroupMotor),ac(ab.Parent.Instant),ac(ab.Parent.Spring)it('should complete when all child motors are complete',function()local ai=af.new({A=1,B=2},false)expect(ai._complete).to.equal(true)ai:setGoal{A=ag.new(3),B=ah.new(4,{frequency=7.5,dampingRatio=1})}expect(ai._complete).to.equal(false)ai:step(1.6666666666666665E-2)expect(ai._complete).to.equal(false)for aj=1,30 do ai:step(1.6666666666666665E-2)end expect(ai._complete).to.equal(true)end)it('should start when the goal is set',function()local ai,aj=af.new({A=0},false),false ai:onStart(function()aj=not aj end)ai:setGoal{A=ag.new(1)}expect(aj).to.equal(true)ai:setGoal{A=ag.new(1)}expect(aj).to.equal(false)end)it('should properly return all values',function()local ai=af.new({A=1,B=2},false)local aj=ai:getValue()expect(aj.A).to.equal(1)expect(aj.B).to.equal(2)end)it('should error when a goal is given to GroupMotor.new',function()local ai=pcall(function()af.new(ag.new(0))end)expect(ai).to.equal(false)end)it([[should error when a single goal is provided to GroupMotor:step]],function()local ai=pcall(function()af.new{a=1}:setGoal(ag.new(0))end)expect(ai).to.equal(false)end)end end,
[35]=function()local aa,ab,ac,ad,ae=b(35)local af={}af.__index=af function af.new(ag)return setmetatable({_targetValue=ag},af)end function af.step(ag)return{complete=true,value=ag._targetValue}end return af end,
[36]=function()local aa,ab,ac,ad,ae=b(36)return function()local af=ac(ab.Parent.Instant)it('should return a completed state with the provided value',function()local ag=af.new(1.23)local ah=ag:step(0.1,{value=0,complete=false})expect(ah.complete).to.equal(true)expect(ah.value).to.equal(1.23)end)end end,
[37]=function()local aa,ab,ac,ad,ae=b(37)local af={}af.__index=af function af.new(ag,ah)assert(ag,'Missing argument #1: targetValue')ah=ah or{}return setmetatable({_targetValue=ag,_velocity=ah.velocity or 1},af)end function af.step(ag,ah,ai)local aj,c,d=ah.value,ag._velocity,ag._targetValue local e=ai*c local f=e>=math.abs(d-aj)aj=aj+e*(d>aj and 1 or-1)if f then aj=ag._targetValue c=0 end return{complete=f,value=aj,velocity=c}end return af end,
[38]=function()local aa,ab,ac,ad,ae=b(38)return function()local af,ag=ac(ab.Parent.SingleMotor),ac(ab.Parent.Linear)describe('completed state',function()local ah,ai=af.new(0,false),ag.new(1,{velocity=1})ah:setGoal(ai)for aj=1,60 do ah:step(1.6666666666666665E-2)end it('should complete',function()expect(ah._state.complete).to.equal(true)end)it('should be exactly the goal value when completed',function()expect(ah._state.value).to.equal(1)end)end)describe('uncompleted state',function()local ah,ai=af.new(0,false),ag.new(1,{velocity=1})ah:setGoal(ai)for aj=1,59 do ah:step(1.6666666666666665E-2)end it('should be uncomplete',function()expect(ah._state.complete).to.equal(false)end)end)describe('negative velocity',function()local ah,ai=af.new(1,false),ag.new(0,{velocity=1})ah:setGoal(ai)for aj=1,60 do ah:step(1.6666666666666665E-2)end it('should complete',function()expect(ah._state.complete).to.equal(true)end)it('should be exactly the goal value when completed',function()expect(ah._state.value).to.equal(0)end)end)end end,
[39]=function()local aa,ab,ac,ad,ae=b(39)local af={}af.__index=af function af.new(ag,ah)return setmetatable({signal=ag,connected=true,_handler=ah},af)end function af.disconnect(ag)if ag.connected then ag.connected=false for ah,ai in pairs(ag.signal._connections)do if ai==ag then table.remove(ag.signal._connections,ah)return end end end end local ag={}ag.__index=ag function ag.new()return setmetatable({_connections={},_threads={}},ag)end function ag.fire(ah,...)if setthreadidentity then pcall(setthreadidentity,8)end for ai,aj in pairs(ah._connections)do pcall(aj._handler,...)end for c,d in pairs(ah._threads)do coroutine.resume(d,...)end ah._threads={}end function ag.connect(ah,aj)local c=af.new(ah,aj)table.insert(ah._connections,c)return c end function ag.wait(ah)table.insert(ah._threads,coroutine.running())return coroutine.yield()end return ag end,
[40]=function()local aa,ab,ac,ad,ae=b(40)return function()local af=ac(ab.Parent.Signal)it('should invoke all connections, instantly',function()local ag,ah,aj=(af.new())ag:connect(function(c)ah=c end)ag:connect(function(c)aj=c end)ag:fire'hello'expect(ah).to.equal'hello'expect(aj).to.equal'hello'end)it('should return values when :wait() is called',function()local ag=af.new()spawn(function()ag:fire(123,'hello')end)local ah,aj=ag:wait()expect(ah).to.equal(123)expect(aj).to.equal'hello'end)it('should properly handle disconnections',function()local ag,ah=af.new(),false local aj=ag:connect(function()ah=true end)aj:disconnect()ag:fire()expect(ah).to.equal(false)end)end end,
[41]=function()local aa,ab,ac,ad,ae=b(41)local af=ac(ab.Parent.BaseMotor)local ag=setmetatable({},af)ag.__index=ag function ag.new(ah,aj)assert(ah,'Missing argument #1: initialValue')assert(typeof(ah)=='number','initialValue must be a number!')local c=setmetatable(af.new(),ag)if aj~=nil then c._useImplicitConnections=aj else c._useImplicitConnections=true end c._goal=nil c._state={complete=true,value=ah}return c end function ag.step(ah,aj)if ah._state.complete then return true end local c=ah._goal:step(ah._state,aj)ah._state=c ah._onStep:fire(c.value)if c.complete then if ah._useImplicitConnections then ah:stop()end ah._onComplete:fire()end return c.complete end function ag.getValue(ah)return ah._state.value end function ag.setGoal(ah,aj)ah._state.complete=false ah._goal=aj ah._onStart:fire()if ah._useImplicitConnections then ah:start()end end function ag.__tostring(ah)return'Motor(Single)'end return ag end,
[42]=function()local aa,ab,ac,ad,ae=b(42)return function()local af,ag=ac(ab.Parent.SingleMotor),ac(ab.Parent.Instant)it('should assign new state on step',function()local ah=af.new(0,false)ah:setGoal(ag.new(5))ah:step(1.6666666666666665E-2)expect(ah._state.complete).to.equal(true)expect(ah._state.value).to.equal(5)end)it([[should invoke onComplete listeners when the goal is completed]],function()local ah,aj=af.new(0,false),false ah:onComplete(function()aj=true end)ah:setGoal(ag.new(5))ah:step(1.6666666666666665E-2)expect(aj).to.equal(true)end)it('should start when the goal is set',function()local ah,aj=af.new(0,false),false ah:onStart(function()aj=not aj end)ah:setGoal(ag.new(5))expect(aj).to.equal(true)ah:setGoal(ag.new(5))expect(aj).to.equal(false)end)end end,
[43]=function()local aa,ab,ac,ad,ae=b(43)local af,ag,ah,aj=0.001,0.001,0.0001,{}aj.__index=aj function aj.new(c,d)assert(c,'Missing argument #1: targetValue')d=d or{}return setmetatable({_targetValue=c,_frequency=d.frequency or 4,_dampingRatio=d.dampingRatio or 1},aj)end function aj.step(c,d,e)local f,g,h,i,j=c._dampingRatio,c._frequency*2*math.pi,c._targetValue,d.value,d.velocity or 0 local k,l,m,n=i-h,(math.exp(-f*g*e))if f==1 then m=(k*(1+g*e)+j*e)*l+h n=(j*(1-g*e)-k*(g*g*e))*l elseif f<1 then local o=math.sqrt(1-f*f)local p,s,t=math.cos(g*o*e),(math.sin(g*o*e))if o>ah then t=s/o else local u=e*g t=u+((u*u)*(o*o)*(o*o)/20-o*o)*(u*u*u)/6 end local u if g*o>ah then u=s/(g*o)else local v=g*o u=e+((e*e)*(v*v)*(v*v)/20-v*v)*(e*e*e)/6 end m=(k*(p+f*t)+j*u)*l+h n=(j*(p-t*f)-k*(t*g))*l else local o=math.sqrt(f*f-1)local p,s=-g*(f-o),-g*(f+o)local t=(j-k*p)/(2*g*o)local u=k-t local v,w=u*math.exp(p*e),t*math.exp(s*e)m=v+w+h n=v*p+w*s end local o=math.abs(n)<af and math.abs(m-h)<ag return{complete=o,value=o and h or m,velocity=n}end return aj end,
[44]=function()local aa,ab,ac,ad,ae=b(44)return function()local af,ag=ac(ab.Parent.SingleMotor),ac(ab.Parent.Spring)describe('completed state',function()local ah,aj=af.new(0,false),ag.new(1,{frequency=2,dampingRatio=0.75})ah:setGoal(aj)for c=1,100 do ah:step(1.6666666666666665E-2)end it('should complete',function()expect(ah._state.complete).to.equal(true)end)it('should be exactly the goal value when completed',function()expect(ah._state.value).to.equal(1)end)end)it('should inherit velocity',function()local ah=af.new(0,false)ah._state={complete=false,value=0,velocity=-5}local aj=ag.new(1,{frequency=2,dampingRatio=1})ah:setGoal(aj)ah:step(1.6666666666666665E-2)expect(ah._state.velocity<0).to.equal(true)end)end end,
[45]=function()local aa,ab,ac,ad,ae=b(45)local af=function(af)local ag=tostring(af):match'^Motor%((.+)%)$'if ag then return true,ag else return false end end return af end,
[46]=function()local aa,ab,ac,ad,ae=b(46)return function()local af,ag,ah=ac(ab.Parent.isMotor),ac(ab.Parent.SingleMotor),ac(ab.Parent.GroupMotor)local aj,c=ag.new(0),ah.new{}it('should properly detect motors',function()expect(af(aj)).to.equal(true)expect(af(c)).to.equal(true)end)it("shouldn't detect things that aren't motors",function()expect(af{}).to.equal(false)end)it('should return the proper motor type',function()local d,e=af(aj)local f,g=af(c)expect(e).to.equal'Single'expect(g).to.equal'Group'end)end end,
[47]=function()local aa,ab,ac,ad,ae=b(47)local af={Names={'Dark','Darker','Light','Aqua','Amethyst','Rose'}}for ag,ah in next,ab:GetChildren()do local aj=ac(ah)af[aj.Name]=aj end return af end,
[48]=function()local aa,ab,ac,ad,ae=b(48)return{Name='Amethyst',Accent=Color3.fromRGB(97,62,167),AcrylicMain=Color3.fromRGB(20,20,20),AcrylicBorder=Color3.fromRGB(110,90,130),AcrylicGradient=ColorSequence.new(Color3.fromRGB(85,57,139),Color3.fromRGB(40,25,65)),AcrylicNoise=0.92,TitleBarLine=Color3.fromRGB(95,75,110),Tab=Color3.fromRGB(160,140,180),Element=Color3.fromRGB(140,120,160),ElementBorder=Color3.fromRGB(60,50,70),InElementBorder=Color3.fromRGB(100,90,110),ElementTransparency=0.87,ToggleSlider=Color3.fromRGB(140,120,160),ToggleToggled=Color3.fromRGB(0,0,0),SliderRail=Color3.fromRGB(140,120,160),DropdownFrame=Color3.fromRGB(170,160,200),DropdownHolder=Color3.fromRGB(60,45,80),DropdownBorder=Color3.fromRGB(50,40,65),DropdownOption=Color3.fromRGB(140,120,160),Keybind=Color3.fromRGB(140,120,160),Input=Color3.fromRGB(140,120,160),InputFocused=Color3.fromRGB(20,10,30),InputIndicator=Color3.fromRGB(170,150,190),Dialog=Color3.fromRGB(60,45,80),DialogHolder=Color3.fromRGB(45,30,65),DialogHolderLine=Color3.fromRGB(40,25,60),DialogButton=Color3.fromRGB(60,45,80),DialogButtonBorder=Color3.fromRGB(95,80,110),DialogBorder=Color3.fromRGB(85,70,100),DialogInput=Color3.fromRGB(70,55,85),DialogInputLine=Color3.fromRGB(175,160,190),Text=Color3.fromRGB(240,240,240),SubText=Color3.fromRGB(170,170,170),Hover=Color3.fromRGB(140,120,160),HoverChange=0.04}end,
[49]=function()local aa,ab,ac,ad,ae=b(49)return{Name='Aqua',Accent=Color3.fromRGB(60,165,165),AcrylicMain=Color3.fromRGB(20,20,20),AcrylicBorder=Color3.fromRGB(50,100,100),AcrylicGradient=ColorSequence.new(Color3.fromRGB(60,140,140),Color3.fromRGB(40,80,80)),AcrylicNoise=0.92,TitleBarLine=Color3.fromRGB(60,120,120),Tab=Color3.fromRGB(140,180,180),Element=Color3.fromRGB(110,160,160),ElementBorder=Color3.fromRGB(40,70,70),InElementBorder=Color3.fromRGB(80,110,110),ElementTransparency=0.84,ToggleSlider=Color3.fromRGB(110,160,160),ToggleToggled=Color3.fromRGB(0,0,0),SliderRail=Color3.fromRGB(110,160,160),DropdownFrame=Color3.fromRGB(160,200,200),DropdownHolder=Color3.fromRGB(40,80,80),DropdownBorder=Color3.fromRGB(40,65,65),DropdownOption=Color3.fromRGB(110,160,160),Keybind=Color3.fromRGB(110,160,160),Input=Color3.fromRGB(110,160,160),InputFocused=Color3.fromRGB(20,10,30),InputIndicator=Color3.fromRGB(130,170,170),Dialog=Color3.fromRGB(40,80,80),DialogHolder=Color3.fromRGB(30,60,60),DialogHolderLine=Color3.fromRGB(25,50,50),DialogButton=Color3.fromRGB(40,80,80),DialogButtonBorder=Color3.fromRGB(80,110,110),DialogBorder=Color3.fromRGB(50,100,100),DialogInput=Color3.fromRGB(45,90,90),DialogInputLine=Color3.fromRGB(130,170,170),Text=Color3.fromRGB(240,240,240),SubText=Color3.fromRGB(170,170,170),Hover=Color3.fromRGB(110,160,160),HoverChange=0.04}end,
[50]=function()local aa,ab,ac,ad,ae=b(50)return{Name='Dark',Accent=Color3.fromRGB(96,205,255),AcrylicMain=Color3.fromRGB(60,60,60),AcrylicBorder=Color3.fromRGB(90,90,90),AcrylicGradient=ColorSequence.new(Color3.fromRGB(40,40,40),Color3.fromRGB(40,40,40)),AcrylicNoise=0.9,TitleBarLine=Color3.fromRGB(75,75,75),Tab=Color3.fromRGB(120,120,120),Element=Color3.fromRGB(120,120,120),ElementBorder=Color3.fromRGB(35,35,35),InElementBorder=Color3.fromRGB(90,90,90),ElementTransparency=0.87,ToggleSlider=Color3.fromRGB(120,120,120),ToggleToggled=Color3.fromRGB(0,0,0),SliderRail=Color3.fromRGB(120,120,120),DropdownFrame=Color3.fromRGB(160,160,160),DropdownHolder=Color3.fromRGB(45,45,45),DropdownBorder=Color3.fromRGB(35,35,35),DropdownOption=Color3.fromRGB(120,120,120),Keybind=Color3.fromRGB(120,120,120),Input=Color3.fromRGB(160,160,160),InputFocused=Color3.fromRGB(10,10,10),InputIndicator=Color3.fromRGB(150,150,150),Dialog=Color3.fromRGB(45,45,45),DialogHolder=Color3.fromRGB(35,35,35),DialogHolderLine=Color3.fromRGB(30,30,30),DialogButton=Color3.fromRGB(45,45,45),DialogButtonBorder=Color3.fromRGB(80,80,80),DialogBorder=Color3.fromRGB(70,70,70),DialogInput=Color3.fromRGB(55,55,55),DialogInputLine=Color3.fromRGB(160,160,160),Text=Color3.fromRGB(240,240,240),SubText=Color3.fromRGB(170,170,170),Hover=Color3.fromRGB(120,120,120),HoverChange=0.07}end,
[51]=function()local aa,ab,ac,ad,ae=b(51)return{Name='Darker',Accent=Color3.fromRGB(72,138,182),AcrylicMain=Color3.fromRGB(30,30,30),AcrylicBorder=Color3.fromRGB(60,60,60),AcrylicGradient=ColorSequence.new(Color3.fromRGB(25,25,25),Color3.fromRGB(15,15,15)),AcrylicNoise=0.94,TitleBarLine=Color3.fromRGB(65,65,65),Tab=Color3.fromRGB(100,100,100),Element=Color3.fromRGB(70,70,70),ElementBorder=Color3.fromRGB(25,25,25),InElementBorder=Color3.fromRGB(55,55,55),ElementTransparency=0.82,DropdownFrame=Color3.fromRGB(120,120,120),DropdownHolder=Color3.fromRGB(35,35,35),DropdownBorder=Color3.fromRGB(25,25,25),Dialog=Color3.fromRGB(35,35,35),DialogHolder=Color3.fromRGB(25,25,25),DialogHolderLine=Color3.fromRGB(20,20,20),DialogButton=Color3.fromRGB(35,35,35),DialogButtonBorder=Color3.fromRGB(55,55,55),DialogBorder=Color3.fromRGB(50,50,50),DialogInput=Color3.fromRGB(45,45,45),DialogInputLine=Color3.fromRGB(120,120,120)}end,
[52]=function()local aa,ab,ac,ad,ae=b(52)return{Name='Light',Accent=Color3.fromRGB(0,103,192),AcrylicMain=Color3.fromRGB(200,200,200),AcrylicBorder=Color3.fromRGB(120,120,120),AcrylicGradient=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(255,255,255)),AcrylicNoise=0.96,TitleBarLine=Color3.fromRGB(160,160,160),Tab=Color3.fromRGB(90,90,90),Element=Color3.fromRGB(255,255,255),ElementBorder=Color3.fromRGB(180,180,180),InElementBorder=Color3.fromRGB(150,150,150),ElementTransparency=0.65,ToggleSlider=Color3.fromRGB(40,40,40),ToggleToggled=Color3.fromRGB(255,255,255),SliderRail=Color3.fromRGB(40,40,40),DropdownFrame=Color3.fromRGB(200,200,200),DropdownHolder=Color3.fromRGB(240,240,240),DropdownBorder=Color3.fromRGB(200,200,200),DropdownOption=Color3.fromRGB(150,150,150),Keybind=Color3.fromRGB(120,120,120),Input=Color3.fromRGB(200,200,200),InputFocused=Color3.fromRGB(100,100,100),InputIndicator=Color3.fromRGB(80,80,80),Dialog=Color3.fromRGB(255,255,255),DialogHolder=Color3.fromRGB(240,240,240),DialogHolderLine=Color3.fromRGB(228,228,228),DialogButton=Color3.fromRGB(255,255,255),DialogButtonBorder=Color3.fromRGB(190,190,190),DialogBorder=Color3.fromRGB(140,140,140),DialogInput=Color3.fromRGB(250,250,250),DialogInputLine=Color3.fromRGB(160,160,160),Text=Color3.fromRGB(0,0,0),SubText=Color3.fromRGB(40,40,40),Hover=Color3.fromRGB(50,50,50),HoverChange=0.16}end,
[53]=function()local aa,ab,ac,ad,ae=b(53)return{Name='Rose',Accent=Color3.fromRGB(180,55,90),AcrylicMain=Color3.fromRGB(40,40,40),AcrylicBorder=Color3.fromRGB(130,90,110),AcrylicGradient=ColorSequence.new(Color3.fromRGB(190,60,135),Color3.fromRGB(165,50,70)),AcrylicNoise=0.92,TitleBarLine=Color3.fromRGB(140,85,105),Tab=Color3.fromRGB(180,140,160),Element=Color3.fromRGB(200,120,170),ElementBorder=Color3.fromRGB(110,70,85),InElementBorder=Color3.fromRGB(120,90,90),ElementTransparency=0.86,ToggleSlider=Color3.fromRGB(200,120,170),ToggleToggled=Color3.fromRGB(0,0,0),SliderRail=Color3.fromRGB(200,120,170),DropdownFrame=Color3.fromRGB(200,160,180),DropdownHolder=Color3.fromRGB(120,50,75),DropdownBorder=Color3.fromRGB(90,40,55),DropdownOption=Color3.fromRGB(200,120,170),Keybind=Color3.fromRGB(200,120,170),Input=Color3.fromRGB(200,120,170),InputFocused=Color3.fromRGB(20,10,30),InputIndicator=Color3.fromRGB(170,150,190),Dialog=Color3.fromRGB(120,50,75),DialogHolder=Color3.fromRGB(95,40,60),DialogHolderLine=Color3.fromRGB(90,35,55),DialogButton=Color3.fromRGB(120,50,75),DialogButtonBorder=Color3.fromRGB(155,90,115),DialogBorder=Color3.fromRGB(100,70,90),DialogInput=Color3.fromRGB(135,55,80),DialogInputLine=Color3.fromRGB(190,160,180),Text=Color3.fromRGB(240,240,240),SubText=Color3.fromRGB(170,170,170),Hover=Color3.fromRGB(200,120,170),HoverChange=0.04}end,
[54]=function()
local c,d,e,f,g=b(54)
local Root=d.Parent.Parent
local Creator=e(Root.Creator)
local New=Creator.New

local Divider={}
Divider.__index=Divider
Divider.__type='Divider'

function Divider.New(self,arg1,arg2)
    local config={}
    if type(arg1)=='table'then
        config=arg1
    elseif type(arg2)=='table'then
        config=arg2
    elseif type(arg1)=='string'then
        config={Title=arg1}
    end

    local title=config.Title or config.Text or''
    local icon=self.Library:GetIcon(config.Icon)

    local DivObj={
        Title=tostring(title),
        UserVisible=(config.Visible~=false),
        SearchVisible=true,
        Type='Divider'
    }

    local LeftLine=New('Frame',{
        Size=UDim2.new(0.5,-10,0,1),
        Position=UDim2.new(0,4,0.5,0),
        AnchorPoint=Vector2.new(0,0.5),
        BackgroundTransparency=0.45,
        ThemeTag={BackgroundColor3='TitleBarLine'}
    })

    local RightLine=New('Frame',{
        Size=UDim2.new(0.5,-10,0,1),
        Position=UDim2.new(1,-4,0.5,0),
        AnchorPoint=Vector2.new(1,0.5),
        BackgroundTransparency=0.45,
        ThemeTag={BackgroundColor3='TitleBarLine'}
    })

    local FullLine=New('Frame',{
        Size=UDim2.new(1,-8,0,1),
        Position=UDim2.fromScale(0.5,0.5),
        AnchorPoint=Vector2.new(0.5,0.5),
        BackgroundTransparency=0.45,
        ThemeTag={BackgroundColor3='TitleBarLine'}
    })

    local IconImg=New('ImageLabel',{
        Image=icon or'',
        Size=UDim2.fromOffset(12,12),
        BackgroundTransparency=1,
        Visible=(icon~=nil),
        LayoutOrder=1,
        ThemeTag={ImageColor3='SubText'}
    })

    local Label=New('TextLabel',{
        FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Medium,Enum.FontStyle.Normal),
        Text=DivObj.Title,
        RichText=true,
        TextSize=11,
        AutomaticSize=Enum.AutomaticSize.X,
        Size=UDim2.fromOffset(0,14),
        BackgroundTransparency=1,
        LayoutOrder=2,
        ThemeTag={TextColor3='SubText'}
    })

    local CenterHolder=New('Frame',{
        Position=UDim2.fromScale(0.5,0.5),
        AnchorPoint=Vector2.new(0.5,0.5),
        AutomaticSize=Enum.AutomaticSize.X,
        Size=UDim2.fromOffset(0,16),
        BackgroundTransparency=1
    },{
        New('UIListLayout',{
            FillDirection=Enum.FillDirection.Horizontal,
            VerticalAlignment=Enum.VerticalAlignment.Center,
            HorizontalAlignment=Enum.HorizontalAlignment.Center,
            SortOrder=Enum.SortOrder.LayoutOrder,
            Padding=UDim.new(0,5)
        }),
        IconImg,
        Label
    })

    DivObj.Frame=New('Frame',{
        Size=UDim2.new(1,0,0,DivObj.Title~=''and 20 or 10),
        BackgroundTransparency=1,
        LayoutOrder=7,
        Parent=self.Container
    },{
        FullLine,
        LeftLine,
        RightLine,
        CenterHolder
    })

    local function RefreshLayout()
        local hasText=(DivObj.Title~='')
        FullLine.Visible=not hasText
        LeftLine.Visible=hasText
        RightLine.Visible=hasText
        CenterHolder.Visible=hasText
        DivObj.Frame.Size=UDim2.new(1,0,0,hasText and 20 or 10)
        if hasText then
            local badgeW=CenterHolder.AbsoluteSize.X+16
            LeftLine.Size=UDim2.new(0.5,-math.max(math.floor(badgeW/2),14),0,1)
            RightLine.Size=UDim2.new(0.5,-math.max(math.floor(badgeW/2),14),0,1)
        end
    end

    Creator.AddSignal(CenterHolder:GetPropertyChangedSignal'AbsoluteSize',RefreshLayout)

    function DivObj.SetTitle(self,newText)
        DivObj.Title=tostring(newText or'')
        Label.Text=DivObj.Title
        RefreshLayout()
    end
    DivObj.SetText=DivObj.SetTitle

    function DivObj.UpdateVisibility(self)
        DivObj.Frame.Visible=(DivObj.UserVisible~=false)and(DivObj.SearchVisible~=false)
    end

    function DivObj.SetVisible(self,vis)
        DivObj.UserVisible=(vis~=false)
        DivObj:UpdateVisibility()
    end

    function DivObj.GetSearchText(self)
        return(DivObj.Title or''):gsub('<[^>]+>',''):lower()
    end

    function DivObj.Destroy(self)
        DivObj.Frame:Destroy()
    end

    RefreshLayout()
    DivObj:UpdateVisibility()
    if self.Context and self.Context.RegisterSearchItem then
        self.Context:RegisterSearchItem(DivObj)
    end
    return DivObj
end

return Divider
end,
[55]=function()
local c,d,e,f,g=b(55)
local Root=d.Parent.Parent
local Creator=e(Root.Creator)
local New=Creator.New

local StatCard={}
StatCard.__index=StatCard
StatCard.__type='StatCard'

function StatCard.New(self,arg1,arg2)
    local Library=self.Library
    local idx=nil
    local config={}
    if type(arg1)=='string'and type(arg2)=='table'then
        idx=arg1
        config=arg2
    elseif type(arg1)=='table'then
        config=arg1
        idx=config.Id or config.Idx
    end

    local isGrid=(type(config.Stats)=='table')
    local statsList=isGrid and config.Stats or{
        {
            Key=config.Key or config.Title or'Value',
            Title=config.Title or'Stat',
            Value=config.Value or config.Content or'0',
            SubValue=config.SubValue or config.Description or config.Badge,
            Icon=config.Icon,
            Color=config.Color
        }
    }

    local columns=config.Columns or(isGrid and math.clamp(#statsList,1,3)or 1)
    local hasHeader=isGrid and(config.Title~=nil and config.Title~='')

    local CardObj={
        Type='StatCard',
        Tiles={},
        TilesByKey={},
        TitleText=tostring(config.Title or''),
        DescText=tostring(config.Description or''),
        TooltipText='',
        Locked=false,
        UserVisible=(config.Visible~=false),
        SearchVisible=true
    }

    local HeaderTitle=New('TextLabel',{
        FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Medium,Enum.FontStyle.Normal),
        Text=CardObj.TitleText,
        RichText=true,
        TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.new(1,-16,0,16),
        Position=UDim2.fromOffset(10,7),
        BackgroundTransparency=1,
        Visible=hasHeader,
        ThemeTag={TextColor3='SubText'}
    })

    local GridLayout=New('UIGridLayout',{
        CellPadding=UDim2.fromOffset(6,6),
        CellSize=UDim2.new(1/math.max(columns,1),-6,0,50),
        SortOrder=Enum.SortOrder.LayoutOrder
    })

    local GridHolder=New('Frame',{
        Size=UDim2.new(1,hasHeader and-16 or 0,0,50),
        Position=UDim2.fromOffset(hasHeader and 8 or 0,hasHeader and 26 or 0),
        BackgroundTransparency=1
    },{GridLayout})

    CardObj.Frame=New('Frame',{
        Size=UDim2.new(1,0,0,50),
        BackgroundTransparency=hasHeader and 0.89 or 1,
        LayoutOrder=7,
        Parent=self.Container,
        ThemeTag=hasHeader and{
            BackgroundColor3='Element',
            BackgroundTransparency='ElementTransparency'
        }or nil
    },{
        New('UICorner',{CornerRadius=UDim.new(0,5)}),
        New('UIStroke',{
            Transparency=hasHeader and 0.5 or 1,
            ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
            ThemeTag={Color='ElementBorder'}
        }),
        HeaderTitle,
        GridHolder
    })

    local function UpdateCardHeight()
        local gridH=GridLayout.AbsoluteContentSize.Y
        GridHolder.Size=UDim2.new(1,hasHeader and-16 or 0,0,gridH)
        CardObj.Frame.Size=UDim2.new(1,0,0,gridH+(hasHeader and 34 or 0))
    end

    Creator.AddSignal(GridLayout:GetPropertyChangedSignal'AbsoluteContentSize',UpdateCardHeight)

    local function BuildTiles(list)
        for _,child in next,GridHolder:GetChildren()do
            if not child:IsA'UIGridLayout'then
                child:Destroy()
            end
        end
        table.clear(CardObj.Tiles)
        table.clear(CardObj.TilesByKey)

        for i,stat in ipairs(list)do
            local key=stat.Key or stat.Id or stat.Title or i
            local iconAsset=Library:GetIcon(stat.Icon)
            local leftPad=iconAsset and 44 or 10

            local TileChildren={
                New('UICorner',{CornerRadius=UDim.new(0,5)}),
                New('UIStroke',{
                    Transparency=0.5,
                    ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
                    ThemeTag={Color='InElementBorder'}
                })
            }

            local IconImg
            if iconAsset then
                IconImg=New('ImageLabel',{
                    Image=iconAsset,
                    Size=UDim2.fromOffset(16,16),
                    Position=UDim2.fromScale(0.5,0.5),
                    AnchorPoint=Vector2.new(0.5,0.5),
                    BackgroundTransparency=1,
                    ImageColor3=stat.Color or Color3.fromRGB(96,205,255),
                    ThemeTag=(not stat.Color)and{ImageColor3='Accent'}or nil
                })
                table.insert(TileChildren,New('Frame',{
                    Size=UDim2.fromOffset(28,28),
                    Position=UDim2.new(0,8,0.5,0),
                    AnchorPoint=Vector2.new(0,0.5),
                    BackgroundTransparency=0.86,
                    BackgroundColor3=stat.Color or Color3.fromRGB(96,205,255),
                    ThemeTag=(not stat.Color)and{BackgroundColor3='Accent'}or nil
                },{
                    New('UICorner',{CornerRadius=UDim.new(0,6)}),
                    IconImg
                }))
            end

            local TitleLbl=New('TextLabel',{
                FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Medium,Enum.FontStyle.Normal),
                Text=tostring(stat.Title or key),
                RichText=true,
                TextSize=11,
                TextXAlignment=Enum.TextXAlignment.Left,
                Size=UDim2.new(1,-(leftPad+8),0,13),
                Position=UDim2.fromOffset(leftPad,7),
                BackgroundTransparency=1,
                TextTruncate=Enum.TextTruncate.AtEnd,
                ThemeTag={TextColor3='SubText'}
            })

            local ValueLbl=New('TextLabel',{
                FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal),
                Text=tostring(stat.Value or'0'),
                RichText=true,
                TextSize=15,
                TextXAlignment=Enum.TextXAlignment.Left,
                Size=UDim2.new(1,-(leftPad+8),0,18),
                Position=UDim2.fromOffset(leftPad,23),
                BackgroundTransparency=1,
                TextTruncate=Enum.TextTruncate.AtEnd,
                TextColor3=stat.Color or Color3.fromRGB(240,240,240),
                ThemeTag=(not stat.Color)and{TextColor3='Text'}or nil
            })

            local SubLbl=New('TextLabel',{
                FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Medium,Enum.FontStyle.Normal),
                Text=tostring(stat.SubValue or''),
                RichText=true,
                TextSize=10,
                TextXAlignment=Enum.TextXAlignment.Right,
                Size=UDim2.new(0,80,0,13),
                Position=UDim2.new(1,-8,0,7),
                AnchorPoint=Vector2.new(1,0),
                BackgroundTransparency=1,
                Visible=(stat.SubValue~=nil and stat.SubValue~=''),
                ThemeTag={TextColor3='Accent'}
            })

            table.insert(TileChildren,TitleLbl)
            table.insert(TileChildren,ValueLbl)
            table.insert(TileChildren,SubLbl)

            local TileFrame=New('Frame',{
                BackgroundTransparency=0.88,
                LayoutOrder=i,
                Parent=GridHolder,
                ThemeTag={BackgroundColor3='Element',BackgroundTransparency='ElementTransparency'}
            },TileChildren)

            local tileData={
                Key=key,
                Frame=TileFrame,
                TitleLabel=TitleLbl,
                ValueLabel=ValueLbl,
                SubLabel=SubLbl,
                IconImage=IconImg
            }
            CardObj.Tiles[i]=tileData
            CardObj.TilesByKey[key]=tileData
            if stat.Title then CardObj.TilesByKey[stat.Title]=tileData end
        end

        UpdateCardHeight()
    end

    BuildTiles(statsList)

    function CardObj.SetStat(self,keyOrIdx,newVal,newSubVal,newTitle)
        local tile=CardObj.TilesByKey[keyOrIdx]or CardObj.Tiles[keyOrIdx]
        if not tile then return end
        if newVal~=nil then tile.ValueLabel.Text=tostring(newVal)end
        if newSubVal~=nil then
            tile.SubLabel.Text=tostring(newSubVal)
            tile.SubLabel.Visible=(tostring(newSubVal)~='')
        end
        if newTitle~=nil then tile.TitleLabel.Text=tostring(newTitle)end
    end
    CardObj.UpdateStat=CardObj.SetStat

    function CardObj.SetStats(self,newStats)
        if type(newStats)~='table'then return end
        if #newStats>0 and type(newStats[1])=='table'then
            BuildTiles(newStats)
        else
            for k,v in next,newStats do
                if type(v)=='table'then
                    CardObj:SetStat(k,v.Value or v[1],v.SubValue or v[2],v.Title)
                else
                    CardObj:SetStat(k,v)
                end
            end
        end
    end

    function CardObj.SetValue(self,newVal,newSubVal)
        CardObj:SetStat(1,newVal,newSubVal)
    end

    function CardObj.SetSubValue(self,newSubVal)
        local tile=CardObj.Tiles[1]
        if tile then
            tile.SubLabel.Text=tostring(newSubVal or'')
            tile.SubLabel.Visible=(tostring(newSubVal or'')~='')
        end
    end

    function CardObj.SetTitle(self,newTitle)
        CardObj.TitleText=tostring(newTitle or'')
        if hasHeader then
            HeaderTitle.Text=CardObj.TitleText
        elseif CardObj.Tiles[1]then
            CardObj.Tiles[1].TitleLabel.Text=CardObj.TitleText
        end
    end

    function CardObj.SetDesc(self,newDesc)
        CardObj:SetSubValue(newDesc)
    end

    function CardObj.SetTooltip(self,text)
        CardObj.TooltipText=tostring(text or'')
    end

    function CardObj.SetLocked(self,locked,reason)
        CardObj.Locked=not not locked
    end
    CardObj.Lock=function(self,r)return CardObj:SetLocked(true,r)end
    CardObj.Unlock=function(self)return CardObj:SetLocked(false)end
    CardObj.SetDisabled=CardObj.SetLocked

    function CardObj.UpdateVisibility(self)
        local vis=(CardObj.UserVisible~=false)and(CardObj.SearchVisible~=false)
        CardObj.Frame.Visible=vis
        if CardObj.OnVisibilityChanged then
            pcall(CardObj.OnVisibilityChanged,vis)
        end
    end

    function CardObj.SetVisible(self,vis)
        CardObj.UserVisible=(vis~=false)
        CardObj:UpdateVisibility()
    end

    function CardObj.GetSearchText(self)
        local parts={CardObj.TitleText,CardObj.TooltipText}
        for _,t in ipairs(CardObj.Tiles)do
            table.insert(parts,t.TitleLabel.Text or'')
            table.insert(parts,t.ValueLabel.Text or'')
            table.insert(parts,t.SubLabel.Text or'')
        end
        return table.concat(parts,' '):gsub('<[^>]+>',''):lower()
    end

    function CardObj.Destroy(self)
        CardObj.Frame:Destroy()
        if idx then Library.Options[idx]=nil end
    end

    Creator.AddSignal(CardObj.Frame.MouseEnter,function()
        if CardObj.TooltipText and CardObj.TooltipText~=''then
            Library:ShowTooltip(CardObj.TooltipText,CardObj.Frame)
        end
    end)
    Creator.AddSignal(CardObj.Frame.MouseLeave,function()
        if CardObj.TooltipText and CardObj.TooltipText~=''then
            Library:HideTooltip(CardObj.Frame)
        end
    end)

    if config.Tooltip then CardObj:SetTooltip(config.Tooltip)end
    if config.Locked or config.Disabled then CardObj:SetLocked(true,config.LockReason)end
    CardObj:UpdateVisibility()
    if self.Context and self.Context.RegisterSearchItem then
        self.Context:RegisterSearchItem(CardObj)
    end
    if idx then Library.Options[idx]=CardObj end
    return CardObj
end

return StatCard
end
}do local ab,ac,ad,ae,af,ag,ah,aj,c,e,f,g,h,i,j,k=task,setmetatable,error,newproxy,getmetatable,next,table,unpack,coroutine,script,type,require,pcall,getfenv,setfenv,rawget local l,m,n,o,p,s,t,u,v,w,x=ah.insert,ah.remove,ah.freeze or function(l)return l end,ab and ab.defer or function(l,...)local m=c.create(l)c.resume(m,...)return m end,'0.0.0-venv',{},{},{},{},{},{}local y,z={GetChildren=function(y)local z,A=x[y],{}for B in ag,z do l(A,B)end return A end,FindFirstChild=function(y,z)if not z then ad('Argument 1 missing or nil',2)end for A in ag,x[y]do if A.Name==z then return A end end return end,GetFullName=function(y)local z,A=y.Name,y.Parent while A do z=A.Name..'.'..z A=A.Parent end return'VirtualEnv.'..z end},{}for A,B in ag,y do z[A]=function(C,...)if not x[C]then ad("Expected ':' not '.' calling member function "..A,1)end return B(C,...)end end local C=function(C,D,E)local F,G,H,I,J=ac({},{__mode='k'}),function(F)ad(F..' is not a valid (virtual) member of '..C..' "'..D..'"',1)end,function(F)ad('Unable to assign (virtual) property '..F..'. Property is read only',1)end,(ae(true))local K=af(I)K.__index=function(L,M)if M=='ClassName'then return C elseif M=='Name'then return D elseif M=='Parent'then return E elseif C=='StringValue'and M=='Value'then return J else local N=z[M]if N then return N end end for N in ag,F do if N.Name==M then return N end end G(M)end K.__newindex=function(L,M,N)if M=='ClassName'then H(M)elseif M=='Name'then D=N elseif M=='Parent'then if N==I then return end if E~=nil then x[E][I]=nil end E=N if N~=nil then x[N][I]=true end elseif C=='StringValue'and M=='Value'then J=N else G(M)end end K.__tostring=function()return D end x[I]=F if E~=nil then x[E][I]=true end return I end local function D(E,F)local G,H,I,J=E[1],E[2],E[3],E[4]local K=m(I,1)local L=C(H,K,F)s[G]=L if I then for M,N in ag,I do L[M]=N end end if J then for M,N in ag,J do D(N,L)end end return L end local E={}for F,G in ag,a do l(E,D(G))end for H,I in ag,aa do local J=s[H]t[J]=I local K=J.ClassName if K=='LocalScript'or K=='Script'then l(v,J)end end local J=function(J)local K,L=J.ClassName,u[J]if L and K=='ModuleScript'then return aj(L)end local M=t[J]if not M then return end if K=='LocalScript'or K=='Script'then M()return else local N={M()}u[J]=N return aj(N)end end function b(K)local L=s[K]local M=t[L]if not M then return end local N,O,P,Q,R,S,T=false,n{Version=p,Script=e,Shared=w,GetScript=function()return e end,GetShared=function()return w end},L,function(N,...)if x[N]and N.ClassName=='ModuleScript'and t[N]then return J(N)end return g(N,...)end local U,V=function(U,...)if not N then T()end if f(U)=='number'and U>=0 then if U==0 then return S else U=U+1 local V,W=h(i,U)if V and W==R then return S end end end return i(U,...)end,function(U,V,...)if not N then T()end if f(U)=='number'and U>=0 then if U==0 then return j(S,V)else U=U+1 local W,X=h(i,U)if W and X==R then return j(S,V)end end end return j(U,V,...)end function T()R=i(0)local W={maui=O,script=P,require=Q,getfenv=U,setfenv=V}S=ac({},{__index=function(X,Y)local Z=k(S,Y)if Z~=nil then return Z end local _=W[Y]if _~=nil then return _ end return R[Y]end})j(M,S)N=true end return O,P,Q,U,V end for K,L in ag,v do o(J,L)end do local M for N,O in ag,E do if O.ClassName=='ModuleScript'and O.Name=='MainModule'then M=O break end end if M then return J(M)end end end

