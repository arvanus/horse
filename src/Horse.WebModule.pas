unit Horse.WebModule;

interface

uses System.SysUtils, System.IOUtils, System.Classes, Web.HTTPApp, Horse,
  System.RegularExpressions;

type
  THorseResultRegex = record
    Path: string;
    Sucess: Boolean;
    constructor Create(APath: string; ASucess: Boolean);
  end;

  THorseWebModule = class(TWebModule)
    procedure HandlerAction(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
  private
    FHorse: THorse;
    function ValidateRegex(APath: string; ARequest: THorseRequest;
  AResponse: THorseResponse): THorseResultRegex;
    function GenerateExpression(APath: string): string;
  public
    property Horse: THorse read FHorse write FHorse;
    constructor Create(AOwner: TComponent); override;
  end;

var
  WebModuleClass: TComponentClass = THorseWebModule;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}
{$R *.dfm}

constructor THorseWebModule.Create(AOwner: TComponent);
begin
  inherited;
  FHorse := THorse.GetInstance;
end;

function THorseWebModule.GenerateExpression(APath: string): string;
var
  LIdentifier: string;
  LIdentifiers: TArray<string>;
begin
  LIdentifiers := APath.Split(['/']);
  APath := APath.Replace('/', '\/');

  for LIdentifier in LIdentifiers do
  begin
    if LIdentifier.StartsWith(':') then
      APath := APath.Replace(LIdentifier, '(.*)');
  end;

  APath := '^' + APath;
  APath := APath + '$';

  Result := APath;
end;

procedure THorseWebModule.HandlerAction(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: Boolean);
var
  LIdentifiers: TArray<string>;
  LIdentifier, LPath: string;
  LMiddleware: THorseMiddleware;
  LMiddlewares: THorseMiddlewares;
  LRequest: THorseRequest;
  LResponse: THorseResponse;
  LResultRegex: THorseResultRegex;
begin
  LRequest := THorseRequest.Create(Request);
  LResponse := THorseResponse.Create(Response);

  LResultRegex := ValidateRegex(Request.PathInfo, LRequest, LResponse);
  if LResultRegex.Sucess then
  begin
    LIdentifiers := LResultRegex.Path.Split(['/'], ExcludeEmpty);

    for LIdentifier in LIdentifiers do
    begin
      if not LPath.IsEmpty then
        LPath := LPath + '/';
      LPath := LPath + LIdentifier;

      if FHorse.Routes.TryGetValue(LPath, LMiddlewares) then
      begin
        for LMiddleware in LMiddlewares do
        begin
          if (LMiddleware.MethodType = mtAny) or
            (LMiddleware.MethodType = Request.MethodType) then
          begin
            LMiddleware.Callback(LRequest, LResponse);
          end;
        end;
      end;
    end;
  end
  else
  begin
    Response.Content := 'Not Found';
    Response.StatusCode := 404;
  end;
end;

function THorseWebModule.ValidateRegex(APath: string; ARequest: THorseRequest;
  AResponse: THorseResponse): THorseResultRegex;
var
  LMatch: TMatch;
  LRegex: TRegEx;
  LPath: string;
  LIdentifier: string;
  LIdentifiers: TArray<string>;
  LCount: Integer;
begin
  LCount := 1;

  if APath.StartsWith('/') then
    APath := APath.Remove(0, 1);

  if APath.EndsWith('/') then
    APath := APath.Remove(High(APath) - 1, 1);

  for LPath in FHorse.Routes.Keys do
  begin
    LRegex.Create(GenerateExpression(LPath));
    LMatch := LRegex.Match(APath);
    Result.Sucess := LMatch.Success;
    if Result.Sucess then
    begin
      Result.Path := LPath;
      LIdentifiers := LPath.Split(['/']);
      for LIdentifier in LIdentifiers do
      begin
        if LIdentifier.StartsWith(':') then
        begin
          THorseHackRequest(ARequest)
            .GetParams.Add(LIdentifier.Replace(':', ''),
            LMatch.Groups.Item[LCount].Value);
          Inc(LCount);
        end;
      end;
      Break;
    end;
  end;
end;

{ THorseResultRegex }

constructor THorseResultRegex.Create(APath: string; ASucess: Boolean);
begin
  Path := APath;
  Sucess := ASucess;
end;

end.
