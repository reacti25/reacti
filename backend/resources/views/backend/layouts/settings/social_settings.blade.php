@extends('backend.app')

@section('content')
<!--app-content open-->
<div class="app-content main-content mt-0">
    <div class="side-app">

        <!-- CONTAINER -->
        <div class="main-container container-fluid">

            {{-- PAGE-HEADER --}}
            <div class="page-header">
                <div>
                    <h1 class="page-title">Google Client Settings <i class="fa-solid fa-triangle-exclamation text-danger" title="Warning"></i></h1>
                </div>
                <div class="ms-auto pageheader-btn">
                    <ol class="breadcrumb">
                        <li class="breadcrumb-item"><a href="javascript:void(0);">Settings</a></li>
                        <li class="breadcrumb-item active" aria-current="page">Google</li>
                    </ol>
                </div>
            </div>
            {{-- PAGE-HEADER --}}


            <div class="row">
                <div class="col-lg-12 col-xl-12 col-md-12 col-sm-12">
                    <h2 class="card-header">Google Settings</h2>
                    <div class="card box-shadow-0">
                        <div class="card-body">
                            <div class="row mb-4">
                                <label for="google_client_id" class="col-md-3 form-label">Google Client ID</label>
                                <div class="col-md-9">
                                    <input class="form-control" id="google_client_id" type="text" readonly value="{{ $settings['google_client_id'] }}">
                                </div>
                            </div>
                            <div class="row mb-4">
                                <label for="google_client_secret" class="col-md-3 form-label">Google Client Secret</label>
                                <div class="col-md-9">
                                    <input class="form-control" id="google_client_secret" type="text" readonly value="{{ $settings['google_client_secret'] }}">
                                </div>
                            </div>
                            <div class="row mb-4">
                                <label for="google_redirect_url" class="col-md-3 form-label">Google Redirect Url</label>
                                <div class="col-md-9">
                                    <input class="form-control" id="google_redirect_url" type="text" readonly value="{{ $settings['google_redirect_url'] }}">
                                </div>
                            </div>
                            <small class="text-muted">Set through the server environment (GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REDIRECT_URL) at deploy time, not from this page.</small>

                        </div>
                    </div>
                </div>
            </div>

        </div>
    </div>
</div>
<!-- CONTAINER CLOSED -->
@endsection



@push('scripts')
@endpush